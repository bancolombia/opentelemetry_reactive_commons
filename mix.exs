defmodule OpentelemetryReactiveCommons.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :opentelemetry_reactive_commons,
      version: @version,
      elixir: "~> 1.16",
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_ref: "v#{@version}"
      ],
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
      deps: deps(),
      package: package(),
      description: description(),
      source_url: "https://github.com/bancolombia/opentelemetry_reactive_commons"
    ]
  end

  defp description() do
    "OpentelemetryReactiveCommons uses telemetry handlers to create OpenTelemetry spans."
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
      {:dialyxir, "~> 1.4", [only: [:dev, :test], runtime: false]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Juan C Galvis"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/bancolombia/opentelemetry_reactive_commons",
        "About this initiative" => "https://reactivecommons.org"
      }
    ]
  end
end
