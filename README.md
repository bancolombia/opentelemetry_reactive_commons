# OpentelemetryReactiveCommons

OpentelemetryReactiveCommons uses [telemetry](https://hexdocs.pm/telemetry/) handlers to
create `OpenTelemetry` spans from ReactiveCommons command events.

Supported events include events sent, received and processed events and query replies.

## Installation

The package can be installed by adding `opentelemetry_reactive_commons` to your list of
dependencies in `mix.exs`:

```elixir
  def deps do
    [
      {:opentelemetry_reactive_commons, "~> 0.1"}
    ]
  end
```

## Compatibility Matrix

| OpentelemetryReactiveCommons Version | Otel Version | ReactiveCommons Version |
| :----------------------------------- | :----------- | :---------------------- |
|                                      |              |                         |
| v1.0.0                               | v1.0.0       | v1.1.0                  |

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/opentelemetry_reactive_commons](https://hexdocs.pm/opentelemetry_reactive_commons).
