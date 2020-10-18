defmodule NebulexRedisAdapter.MixProject do
  use Mix.Project

  @version "2.0.0-dev"

  def project do
    [
      app: :nebulex_redis_adapter,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),

      # Docs
      name: "NebulexRedisAdapter",
      docs: docs(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test,
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
      {:redix, "~> 0.11"},

      # This is because the adapter tests need some support modules and shared
      # tests from nebulex dependency, and the hex dependency doesn't include
      # the test folder. Hence, to run the tests it is necessary to fetch
      # nebulex dependency directly from GH.
      {:nebulex, nebulex_dep()},
      {:nebulex_cluster, github: "cabol/nebulex_cluster"},
      {:crc, "~> 0.9"},
      {:jchash, "~> 0.1.2", optional: true},

      # Test & Code Analysis
      {:excoveralls, "~> 0.13", only: :test},
      {:benchee, "~> 1.0", optional: true, only: :dev},
      {:benchee_html, "~> 1.0", optional: true, only: :dev},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test]},

      # Docs
      {:ex_doc, "~> 0.23", only: [:dev, :test], runtime: false},
      {:inch_ex, "~> 2.0", only: :docs}
    ]
  end

  defp nebulex_dep do
    if System.get_env("NBX_TEST") do
      # [github: "cabol/nebulex", tag: "v1.1.1", override: true]
      [github: "cabol/nebulex", branch: "master", override: true]
    else
      "~> 1.1"
    end
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
      plt_add_apps: [:nebulex, :jchash],
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
