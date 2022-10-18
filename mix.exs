defmodule NebulexRedisAdapter.MixProject do
  use Mix.Project

  @source_url "https://github.com/cabol/nebulex_redis_adapter"
  @version "2.2.1"
  @nbx_vsn "2.3"

  def project do
    [
      app: :nebulex_redis_adapter,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),

      # Docs
      name: "NebulexRedisAdapter",
      docs: docs(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        check: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # Dialyzer
      dialyzer: dialyzer(),

      # Hex
      package: package(),
      description: "Nebulex adapter for Redis"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      nebulex_dep(),
      {:redix, "~> 1.1"},
      {:crc, "~> 0.10", optional: true},
      {:jchash, "~> 0.1.3", optional: true},
      {:telemetry, "~> 0.4 or ~> 1.0", optional: true},

      # Test & Code Analysis
      {:excoveralls, "~> 0.14", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},

      # Benchmark Test
      {:benchee, "~> 1.1", only: :test},
      {:benchee_html, "~> 1.0", only: :test},

      # Docs
      {:ex_doc, "~> 0.28", only: [:dev, :test], runtime: false}
    ]
  end

  defp nebulex_dep do
    if path = System.get_env("NEBULEX_PATH") do
      {:nebulex, "~> #{@nbx_vsn}", path: path}
    else
      {:nebulex, "~> #{@nbx_vsn}"}
    end
  end

  defp aliases do
    [
      "nbx.setup": [
        "cmd rm -rf nebulex",
        "cmd git clone --depth 1 --branch v#{@nbx_vsn} https://github.com/cabol/nebulex"
      ],
      check: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "coveralls.html",
        "dialyzer --format short"
      ]
    ]
  end

  defp package do
    [
      name: :nebulex_redis_adapter,
      maintainers: ["Carlos Bolanos"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "NebulexRedisAdapter",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/nebulex_redis_adapter",
      source_url: @source_url
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:nebulex, :crc, :jchash],
      plt_file: {:no_warn, "priv/plts/" <> plt_file_name()},
      flags: [
        :unmatched_returns,
        :error_handling,
        :race_conditions,
        :no_opaque,
        :unknown,
        :no_return
      ]
    ]
  end

  defp plt_file_name do
    "dialyzer-#{Mix.env()}-#{System.otp_release()}-#{System.version()}.plt"
  end
end
