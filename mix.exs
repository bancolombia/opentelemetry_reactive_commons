defmodule OpentelemetryReactiveCommons.MixProject do
  use Mix.Project

  def project do
    [
      app: :opentelemetry_reactive_commons,
      version: "1.0.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test,
        sobelow: :test,
        coveralls: :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        "coveralls.lcov": :test
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:opentelemetry_api, "~> 1.0"},
      {:opentelemetry_process_propagator, "~> 0.3"},
      {:opentelemetry_semantic_conventions, "~> 0.2"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:opentelemetry, "~> 1.0", only: [:dev, :test]},
      {:opentelemetry_exporter, "~> 1.0", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", [only: [:dev, :test]]},
      {:credo, "~> 1.7", [only: [:dev, :test], runtime: false]},
      {:sobelow, "~> 0.13", [only: [:dev, :test]]},
      {:dialyxir, "~> 1.4", [only: [:dev, :test], runtime: false]}
    ]
  end
end
