use Mix.Config

# Redis Standalone
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.Standalone,
  version_generator: Nebulex.Version.Timestamp,
  connection_module: NebulexRedisAdapter.Connection,
  conn_opts: [
    host: "127.0.0.1",
    port: 6379
  ]

# Redis test cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.Cluster,
  mode: :cluster,
  version_generator: Nebulex.Version.Timestamp,
  connection_module: NebulexRedisAdapter.Connection,
  nodes: [
    node1: [
      conn_opts: [
        host: "127.0.0.1",
        port: 9001
      ]
    ],
    node2: [
      pool_size: 2,
      conn_opts: [
        url: "redis://127.0.0.1:9002"
      ]
    ],
    node3: [
      conn_opts: [
        host: "127.0.0.1",
        port: 9003
      ]
    ]
  ]

# Redis test clustered cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.RedisCluster,
  mode: :redis_cluster,
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
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.RedisClusterConnError,
  mode: :redis_cluster,
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
        port: 8080
      ]
    ]
  ]

# Redis test clustered cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.RedisClusterWithCustomHashSlot,
  mode: :redis_cluster,
  hash_slot: NebulexRedisAdapter.TestCache.HashSlot,
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
