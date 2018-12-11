use Mix.Config

# Redis test cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache,
  version_generator: Nebulex.Version.Timestamp,
  pools: [
    primary: [
      host: "127.0.0.1",
      port: 6379
    ],
    secondary: [
      url: "redis://localhost:6379",
      pool_size: 2
    ]
  ]
