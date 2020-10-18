use Mix.Config

# Redis Standalone
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.Standalone,
  conn_opts: [
    host: "127.0.0.1",
    port: 6379
  ]

# Redis test cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.Cluster,
  mode: :cluster,
  keyslot: NebulexRedisAdapter.TestCache.Keyslot,
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
  master_nodes: [
    [
      host: "127.0.0.1",
      port: 7000
    ],
    [
      url: "redis://127.0.0.1:7001"
    ],
    [
      url: "redis://127.0.0.1:7002"
    ]
  ],
  conn_opts: [
    host: "127.0.0.1"
  ]

# Redis test clustered cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.RedisClusterConnError,
  mode: :redis_cluster,
  pool_size: 2,
  master_nodes: [
    [
      host: "127.0.0.1",
      port: 10100
    ]
  ],
  conn_opts: [
    host: "127.0.0.1"
  ]

# Redis test clustered cache
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.RedisClusterWithKeyslot,
  mode: :redis_cluster,
  keyslot: NebulexRedisAdapter.TestCache.Keyslot,
  pool_size: 2,
  master_nodes: [
    [
      url: "redis://127.0.0.1:7000"
    ]
  ],
  conn_opts: [
    host: "127.0.0.1"
  ]
