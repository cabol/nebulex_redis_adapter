defmodule NebulexRedisAdapter.MixProject do
  use Mix.Project

  @version "1.1.0"

  def project do
    [
      app: :nebulex_redis_adapter,
      version: @version,
      elixir: "~> 1.6",
      deps: deps(),

      # Docs
      name: "NebulexRedisAdapter",
      docs: docs(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
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

  defp deps do
    [
      {:redix, "~> 0.10"},

      # This is because the adapter tests need some support modules and shared
      # tests from nebulex dependency, and the hex dependency doesn't include
      # the test folder. Hence, to run the tests it is necessary to fetch
      # nebulex dependency directly from GH.
      {:nebulex, nebulex_dep()},
      {:nebulex_cluster, "~> 0.1"},
      {:jchash, "~> 0.1", runtime: false},
      {:crc, "~> 0.9"},

      # Test
      {:excoveralls, "~> 0.11", only: :test},
      {:benchee, "~> 1.0", optional: true, only: :dev},
      {:benchee_html, "~> 1.0", optional: true, only: :dev},

      # Code Analysis
      {:dialyxir, "~> 0.5", optional: true, only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", optional: true, only: [:dev, :test]},

      # Docs
      {:ex_doc, "~> 0.20", only: :dev, runtime: false},
      {:inch_ex, "~> 2.0", only: :docs}
    ]
  end

  defp nebulex_dep do
    if System.get_env("NBX_TEST") do
      [github: "cabol/nebulex", tag: "v1.1.0", override: true]
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
      plt_add_apps: [:mix, :eex, :nebulex, :shards, :jchash],
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
end
