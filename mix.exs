defmodule NebulexRedisAdapter.MixProject do
  use Mix.Project

  @version "2.0.0-rc.1"

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
    []
  end

  defp deps do
    [
      nebulex_dep(),
      {:redix, "~> 1.0"},
      {:crc, "~> 0.10", optional: true},
      {:jchash, "~> 0.1.2", optional: true},

      # Test & Code Analysis
      {:excoveralls, "~> 0.13", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},

      # Benchmark Test
      {:benchee, "~> 1.0", only: :test},
      {:benchee_html, "~> 1.0", only: :test},

      # Docs
      {:ex_doc, "~> 0.23", only: [:dev, :test], runtime: false}
    ]
  end

  defp nebulex_dep do
    if System.get_env("NBX_TEST") do
      # This is because the adapter tests need some support modules and shared
      # tests from nebulex dependency, and the hex dependency doesn't include
      # the test folder. Hence, to run the tests it is necessary to fetch
      # nebulex dependency directly from GH.
      {:nebulex, github: "cabol/nebulex", tag: "v2.0.0-rc.1"}
    else
      {:nebulex, "~> 2.0.0-rc.1"}
    end
  end

  defp aliases do
    [
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
      links: %{"GitHub" => "https://github.com/cabol/nebulex_redis_adapter"}
    ]
  end

  defp docs do
    [
      main: "NebulexRedisAdapter",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/nebulex_redis_adapter",
      source_url: "https://github.com/cabol/nebulex_redis_adapter"
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
