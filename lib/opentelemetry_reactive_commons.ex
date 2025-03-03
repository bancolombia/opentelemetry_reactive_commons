defmodule OpentelemetryReactiveCommons do
  @moduledoc """
  OpentelemetryReactiveCommons uses [telemetry](https://hexdocs.pm/telemetry/) handlers to
  create `OpenTelemetry` spans.

  ## Usage

  In your application start:

      def start(_type, _args) do
        OpentelemetryReactiveCommons.setup()

        # ...
      end

  """

  alias OpenTelemetry.SemanticConventions.Trace
  require Logger
  require Trace
  require OpenTelemetry.Tracer

  @messaging_destination_kind_exchange "exchange"
  @messaging_operation_send "send"
  @messaging_operation_process "process"
  @messaging_protocol "AMQP"
  @messaging_protocol_version "0.9.1"
  @messaging_system "rabbitmq"
  @span_name_publish "PUBLISH"
  @span_name_consume "CONSUME"

  @typedoc "Setup options"
  @type opts :: []

  @doc """
  Initializes and configures the telemetry handlers.
  """
  @spec setup(opts()) :: :ok
  def setup(_opts \\ []) do
    :telemetry.attach(
      {__MODULE__, :message_sent},
      [:async, :message, :sent],
      &__MODULE__.handle_message_sent/4,
      :no_config
    )

    :telemetry.attach(
      {__MODULE__, :message_received},
      [:async, :message, :start],
      &__MODULE__.handle_message_received/4,
      :no_config
    )

    :telemetry.attach(
      {__MODULE__, :message_processed},
      [:async, :message, :completed],
      &__MODULE__.handle_message_processed/4,
      :no_config
    )

    :telemetry.attach(
      {__MODULE__, :message_replied},
      [:async, :message, :replied],
      &__MODULE__.handle_message_replied/4,
      :no_config
    )
  end

  @doc false
  def handle_message_received(_event, _measurements, event, _config) do
    attributes =
      %{
        Trace.messaging_operation() => @messaging_operation_process,
        Trace.messaging_system() => @messaging_system,
        Trace.messaging_destination() => event.msg.meta.exchange,
        Trace.messaging_destination_kind() => @messaging_destination_kind_exchange,
        Trace.messaging_temp_destination() => !event.msg.meta.persistent,
        Trace.messaging_protocol() => @messaging_protocol,
        Trace.messaging_protocol_version() => @messaging_protocol_version,
        Trace.messaging_message_id() => event.msg.meta.message_id,
        Trace.messaging_rabbitmq_routing_key() => event.msg.meta.routing_key,
        :"messaging.rabbitmq.app_id" => event.msg.meta.app_id,
        :"messaging.rabbitmq.content_type" => event.msg.meta.content_type
      }

    :otel_propagator_text_map.extract(map_headers(event.msg.meta.headers))

    span_ctx =
      OpenTelemetry.Tracer.start_span(@span_name_consume, %{
        kind: :consumer,
        attributes: attributes
      })

    OpenTelemetry.Tracer.set_current_span(span_ctx)
  end

  @doc false
  def handle_message_processed(_event, _measurements, event, _config) do
    if event.result !== "success" do
      OpenTelemetry.Tracer.set_status(OpenTelemetry.status(:error, event.result))
    end

    OpenTelemetry.Tracer.end_span()
  end

  @doc false
  def handle_message_replied(_event, _measurements, event, _config) do
    attributes =
      %{
        Trace.messaging_operation() => @messaging_operation_process,
        Trace.messaging_system() => @messaging_system,
        Trace.messaging_destination() => event.meta.exchange,
        Trace.messaging_destination_kind() => @messaging_destination_kind_exchange,
        Trace.messaging_temp_destination() => !event.meta.persistent,
        Trace.messaging_protocol() => @messaging_protocol,
        Trace.messaging_protocol_version() => @messaging_protocol_version,
        Trace.messaging_message_id() => event.meta.message_id,
        Trace.messaging_rabbitmq_routing_key() => event.meta.routing_key,
        :"messaging.rabbitmq.app_id" => event.meta.app_id,
        :"messaging.rabbitmq.content_type" => event.meta.content_type
      }

    :otel_propagator_text_map.extract(map_headers(event.meta.headers))

    span_ctx =
      OpenTelemetry.Tracer.start_span(@span_name_consume, %{
        kind: :consumer,
        attributes: attributes
      })

    if event.result !== :ok do
      OpenTelemetry.Span.set_status(
        span_ctx,
        OpenTelemetry.status(:error, format_error(event.result))
      )
    end

    OpenTelemetry.Span.end_span(span_ctx)
  end

  @doc false
  def handle_message_sent(_event, measurements, meta, _config) do
    duration = measurements.duration
    end_time = :opentelemetry.timestamp()
    start_time = end_time - duration

    attributes =
      %{
        Trace.messaging_operation() => @messaging_operation_send,
        Trace.messaging_system() => @messaging_system,
        Trace.messaging_destination() => meta.exchange,
        Trace.messaging_destination_kind() => @messaging_destination_kind_exchange,
        Trace.messaging_temp_destination() => !meta.options[:persistent],
        Trace.messaging_protocol() => @messaging_protocol,
        Trace.messaging_protocol_version() => @messaging_protocol_version,
        Trace.messaging_message_id() => meta.options[:message_id],
        Trace.messaging_rabbitmq_routing_key() => meta.routing_key,
        :"messaging.rabbitmq.app_id" => meta.options[:app_id],
        :"messaging.rabbitmq.content_type" => meta.options[:content_type]
      }

    parent_context = OpentelemetryProcessPropagator.fetch_ctx(meta.caller)

    parent_token =
      if parent_context != :undefined do
        OpenTelemetry.Ctx.attach(parent_context)
      else
        :undefined
      end

    s =
      OpenTelemetry.Tracer.start_span(@span_name_publish, %{
        start_time: start_time,
        kind: :producer,
        attributes: attributes
      })

    if meta[:result] !== :ok do
      OpenTelemetry.Span.set_status(s, OpenTelemetry.status(:error, format_error(meta.result)))
    end

    OpenTelemetry.Span.end_span(s)

    if parent_token != :undefined do
      OpenTelemetry.Ctx.detach(parent_token)
    end
  end

  defp format_error({:error, reason}), do: inspect(reason)
  defp format_error(reason), do: inspect(reason)

  defp map_headers(headers) do
    Enum.map(headers, fn {k, _y, v} -> {k, v} end)
  end

  defmodule Utils do
    @moduledoc """
    Utils module for OpentelemetryReactiveCommons.

    Helps to propagate headers from the parent process to the child remote process.
    """
    @spec inject(headers :: [{String.t(), term}], from :: GenServer.from()) :: [
            {String.t(), term}
          ]
    def inject(headers, {pid, _}) do
      parent_context = OpentelemetryProcessPropagator.fetch_ctx(pid)
      OpenTelemetry.Ctx.attach(parent_context)
      inject_header(headers, :otel_propagator_text_map.inject([]))
    end

    defp inject_header(headers, []), do: headers

    defp inject_header(headers, [{key, value}]) do
      [{key, :longstr, value} | headers]
    end
  end
end
