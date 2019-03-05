use Mix.Config

# Redis test cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.Standalone,
  version_generator: Nebulex.Version.Timestamp,
  redix_opts: [
    host: "127.0.0.1",
    port: 6379
  ]

# Redis test cache with URL
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.StandaloneWithURL,
  pool_size: 2,
  redix_opts: [
    url: "redis://127.0.0.1:6379"
  ]

# Redis test clustered cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.Clustered,
  version_generator: Nebulex.Version.Timestamp,
  cluster: [
    global_host: "127.0.0.1",
    master_nodes: [
      [
        url: "redis://127.0.0.1:7000"
      ],
      [
        url: "redis://127.0.0.1:7001"
      ],
      [
        host: "127.0.0.1",
        port: 7002
      ]
    ]
  ]

# Redis test clustered cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.ClusteredConnError,
  cluster: [
    global_host: "127.0.0.1",
    master_nodes: [
      [
        url: "redis://127.0.0.1:9000"
      ],
      [
        url: "redis://127.0.0.1:9001"
      ],
      [
        host: "127.0.0.1",
        port: 9002
      ]
    ]
  ]

# Redis test clustered cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.ClusteredWithCustomHashSlot,
  cluster: [
    hash_slot: NebulexRedisAdapter.TestCache.HashSlotGen,
    global_host: "127.0.0.1",
    master_nodes: [
      [
        url: "redis://127.0.0.1:7000"
      ],
      [
        url: "redis://127.0.0.1:7001"
      ],
      [
        host: "127.0.0.1",
        port: 7002
      ]
    ]
  ]
