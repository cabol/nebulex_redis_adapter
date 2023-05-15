import Config

# Standalone mode
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.Standalone,
  conn_opts: [
    host: "127.0.0.1",
    port: 6379
  ]

# Cluster mode
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.ClientCluster,
  mode: :client_side_cluster,
  client_side_cluster: [
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
  ]

# Redis Cluster mode (with Redis >= 7)
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.RedisCluster,
  mode: :redis_cluster,
  redis_cluster: [
    # Configuration endpoints
    configuration_endpoints: [
      endpoint1_conn_opts: [
        host: "127.0.0.1",
        port: 6380,
        password: "password"
      ]
    ],
    # Overrides the master host with the config endpoint, in this case with
    # 127.0.0.1, since for tests we use Docker. For prod this should be false.
    override_master_host: true
  ]

# Redis Cluster mode with errors
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.RedisClusterConnError,
  mode: :redis_cluster,
  pool_size: 2,
  redis_cluster: [
    # Configuration endpoints
    configuration_endpoints: [
      endpoint1_conn_opts: [
        host: "127.0.0.1",
        port: 10100
      ]
    ],
    # Overrides the master host with the config endpoint, in this case with
    # 127.0.0.1, since for tests we use Docker. For prod this should be false.
    override_master_host: true
  ]

# Redis Cluster mode with custom Keyslot
config :nebulex_redis_adapter, NebulexRedisAdapter.TestCache.RedisClusterWithKeyslot,
  mode: :redis_cluster,
  pool_size: 2,
  redis_cluster: [
    # Configuration endpoints
    configuration_endpoints: [
      endpoint1_conn_opts: [
        url: "redis://127.0.0.1:7000"
      ]
    ],
    # Overrides the master host with the config endpoint, in this case with
    # 127.0.0.1, since for tests we use Docker. For prod this should be false.
    override_master_host: true,
    # Custom keyslot
    keyslot: NebulexRedisAdapter.TestCache.Keyslot
  ]
