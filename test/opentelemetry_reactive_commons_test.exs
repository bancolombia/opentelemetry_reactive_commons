defmodule OpentelemetryReactiveCommonsTest do
  @moduledoc """
  Tests for OpentelemetryReactiveCommons.
  """
  use ExUnit.Case, async: false

  require OpenTelemetry.Tracer
  require OpenTelemetry.Span
  require Record

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/otel_span.hrl") do
    Record.defrecord(name, spec)
  end

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry_api/include/opentelemetry.hrl") do
    Record.defrecord(name, spec)
  end

  setup do
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    OpenTelemetry.Tracer.start_span("test")

    on_exit(fn ->
      OpenTelemetry.Tracer.end_span()
    end)
  end

  test "record span on success event procesing" do
    OpentelemetryReactiveCommons.setup()

    msg = %{
      meta: %{
        exchange: "exchange_name",
        persistent: true,
        message_id: "message_id",
        routing_key: "SampleEvent",
        app_id: "app_id",
        content_type: "application/json",
        headers: []
      }
    }

    :telemetry.execute([:async, :message, :start], %{}, %{msg: msg})
    start = :opentelemetry.timestamp()
    Process.sleep(100)

    :telemetry.execute(
      [:async, :message, :completed],
      %{duration: :opentelemetry.timestamp() - start},
      %{msg: msg, transaction: "event.SampleEvent", result: "success"}
    )

    assert_receive {:span,
                    span(
                      name: "CONSUME",
                      kind: :consumer,
                      attributes: attributes,
                      status: status
                    )}

    assert %{
             "messaging.destination": "exchange_name",
             "messaging.destination_kind": "exchange",
             "messaging.message_id": "message_id",
             "messaging.operation": "process",
             "messaging.protocol": "AMQP",
             "messaging.protocol_version": "0.9.1",
             "messaging.rabbitmq.app_id": "app_id",
             "messaging.rabbitmq.content_type": "application/json",
             "messaging.rabbitmq.routing_key": "SampleEvent",
             "messaging.system": "rabbitmq",
             "messaging.temp_destination": false
           } = :otel_attributes.map(attributes)

    assert :undefined = status
  end

  test "records span on failed processing" do
    OpentelemetryReactiveCommons.setup()

    msg = %{
      meta: %{
        exchange: "exchange_name",
        persistent: true,
        message_id: "message_id",
        routing_key: "SampleEvent",
        app_id: "app_id",
        content_type: "application/json",
        headers: []
      }
    }

    :telemetry.execute([:async, :message, :start], %{}, %{msg: msg})
    start = :opentelemetry.timestamp()
    Process.sleep(100)

    :telemetry.execute(
      [:async, :message, :completed],
      %{duration: :opentelemetry.timestamp() - start},
      %{msg: msg, transaction: "event.SampleEvent", result: "failed"}
    )

    assert_receive {:span,
                    span(
                      name: "CONSUME",
                      kind: :consumer,
                      attributes: attributes,
                      status: status
                    )}

    assert %{
             "messaging.destination": "exchange_name",
             "messaging.destination_kind": "exchange",
             "messaging.message_id": "message_id",
             "messaging.operation": "process",
             "messaging.protocol": "AMQP",
             "messaging.protocol_version": "0.9.1",
             "messaging.rabbitmq.app_id": "app_id",
             "messaging.rabbitmq.content_type": "application/json",
             "messaging.rabbitmq.routing_key": "SampleEvent",
             "messaging.system": "rabbitmq",
             "messaging.temp_destination": false
           } = :otel_attributes.map(attributes)

    assert {:status, :error, "failed"} = status
  end

  test "record span on message sent" do
    OpentelemetryReactiveCommons.setup()

    options = [
      persistent: true,
      message_id: "message_id",
      app_id: "app_id",
      content_type: "application/json",
      headers: []
    ]

    :telemetry.execute(
      [:async, :message, :sent],
      %{duration: System.monotonic_time() - System.monotonic_time()},
      %{
        exchange: "exchange_name",
        routing_key: "SampleEvent",
        options: options,
        result: :ok,
        caller: self()
      }
    )

    assert_receive {:span,
                    span(
                      name: "PUBLISH",
                      kind: :producer,
                      attributes: attributes,
                      status: status
                    )}

    assert %{
             "messaging.destination": "exchange_name",
             "messaging.destination_kind": "exchange",
             "messaging.message_id": "message_id",
             "messaging.operation": "send",
             "messaging.protocol": "AMQP",
             "messaging.protocol_version": "0.9.1",
             "messaging.rabbitmq.app_id": "app_id",
             "messaging.rabbitmq.content_type": "application/json",
             "messaging.rabbitmq.routing_key": "SampleEvent",
             "messaging.system": "rabbitmq",
             "messaging.temp_destination": false
           } = :otel_attributes.map(attributes)

    assert :undefined = status
  end

  test "record span on message sent with failure" do
    OpentelemetryReactiveCommons.setup()

    options = [
      persistent: true,
      message_id: "message_id",
      app_id: "app_id",
      content_type: "application/json",
      headers: []
    ]

    :telemetry.execute(
      [:async, :message, :sent],
      %{duration: System.monotonic_time() - System.monotonic_time()},
      %{
        exchange: "exchange_name",
        routing_key: "SampleEvent",
        options: options,
        result: {:error, :closed},
        caller: self()
      }
    )

    assert_receive {:span,
                    span(
                      name: "PUBLISH",
                      kind: :producer,
                      attributes: attributes,
                      status: status
                    )}

    assert %{
             "messaging.destination": "exchange_name",
             "messaging.destination_kind": "exchange",
             "messaging.message_id": "message_id",
             "messaging.operation": "send",
             "messaging.protocol": "AMQP",
             "messaging.protocol_version": "0.9.1",
             "messaging.rabbitmq.app_id": "app_id",
             "messaging.rabbitmq.content_type": "application/json",
             "messaging.rabbitmq.routing_key": "SampleEvent",
             "messaging.system": "rabbitmq",
             "messaging.temp_destination": false
           } = :otel_attributes.map(attributes)

    assert {:status, :error, ":closed"} = status
  end

  test "record span on success query replied" do
    OpentelemetryReactiveCommons.setup()

    meta = %{
      exchange: "exchange_name",
      persistent: true,
      message_id: "message_id",
      routing_key: "SampleEvent",
      app_id: "app_id",
      content_type: "application/json",
      headers: []
    }

    :telemetry.execute(
      [:async, :message, :replied],
      %{duration: :opentelemetry.timestamp()},
      %{meta: meta, result: :ok}
    )

    assert_receive {:span,
                    span(
                      name: "CONSUME",
                      kind: :consumer,
                      attributes: attributes,
                      status: status
                    )}

    assert %{
             "messaging.destination": "exchange_name",
             "messaging.destination_kind": "exchange",
             "messaging.message_id": "message_id",
             "messaging.operation": "process",
             "messaging.protocol": "AMQP",
             "messaging.protocol_version": "0.9.1",
             "messaging.rabbitmq.app_id": "app_id",
             "messaging.rabbitmq.content_type": "application/json",
             "messaging.rabbitmq.routing_key": "SampleEvent",
             "messaging.system": "rabbitmq",
             "messaging.temp_destination": false
           } = :otel_attributes.map(attributes)

    assert :undefined = status
  end

  test "record span on success query replied but no process waiting response" do
    OpentelemetryReactiveCommons.setup()

    meta = %{
      exchange: "exchange_name",
      persistent: true,
      message_id: "message_id",
      routing_key: "SampleEvent",
      app_id: "app_id",
      content_type: "application/json",
      headers: []
    }

    :telemetry.execute(
      [:async, :message, :replied],
      %{duration: :opentelemetry.timestamp()},
      %{meta: meta, result: :no_route}
    )

    assert_receive {:span,
                    span(
                      name: "CONSUME",
                      kind: :consumer,
                      attributes: attributes,
                      status: status
                    )}

    assert %{
             "messaging.destination": "exchange_name",
             "messaging.destination_kind": "exchange",
             "messaging.message_id": "message_id",
             "messaging.operation": "process",
             "messaging.protocol": "AMQP",
             "messaging.protocol_version": "0.9.1",
             "messaging.rabbitmq.app_id": "app_id",
             "messaging.rabbitmq.content_type": "application/json",
             "messaging.rabbitmq.routing_key": "SampleEvent",
             "messaging.system": "rabbitmq",
             "messaging.temp_destination": false
           } = :otel_attributes.map(attributes)

    assert {:status, :error, ":no_route"} = status
  end

  test "Should inject the traceparent header" do
    OpenTelemetry.Tracer.with_span "test" do
      headers = OpentelemetryReactiveCommons.Utils.inject([], {self(), nil})
      assert [{"traceparent", :longstr, _}] = headers
    end
  end
end
