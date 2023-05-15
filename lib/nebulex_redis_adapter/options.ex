defmodule NebulexRedisAdapter.Options do
  @moduledoc false

  import Nebulex.Helpers

  # Start option definitions (runtime)
  start_opts_defs = [
    mode: [
      type: {:in, [:standalone, :redis_cluster, :client_side_cluster]},
      required: false,
      default: :standalone,
      doc: """
      Redis configuration mode.

        * `:standalone` - A single Redis instance. See the
          ["Standalone"](#module-standalone) section in the
          module documentation for more options.
        * `:redis_cluster` - Redis Cluster setup. See the
          ["Redis Cluster"](#module-redis-cluster) section in the
          module documentation for more options.
        * `:client_side_cluster` - See the
          ["Client-side Cluster"](#module-client-side-cluster) section in the
          module documentation for more options.

      """
    ],
    pool_size: [
      type: :pos_integer,
      required: false,
      doc: """
      The number of connections that will be started by the adapter
      (based on the `:mode`). The default value is `System.schedulers_online()`.
      """
    ],
    serializer: [
      type: {:custom, __MODULE__, :validate_behaviour, [NebulexRedisAdapter.Serializer]},
      required: false,
      doc: """
      Custom serializer module implementing the `NebulexRedisAdapter.Serializer`
      behaviour.
      """
    ],
    serializer_opts: [
      type: :keyword_list,
      required: false,
      default: [],
      doc: """
      Custom serializer options.
      """,
      keys: [
        encode_key: [
          type: :keyword_list,
          required: false,
          default: [],
          doc: """
          Options for encoding the key.
          """
        ],
        encode_value: [
          type: :keyword_list,
          required: false,
          default: [],
          doc: """
          Options for encoding the value.
          """
        ],
        decode_key: [
          type: :keyword_list,
          required: false,
          default: [],
          doc: """
          Options for decoding the key.
          """
        ],
        decode_value: [
          type: :keyword_list,
          required: false,
          default: [],
          doc: """
          Options for decoding the value.
          """
        ]
      ]
    ],
    conn_opts: [
      type: :keyword_list,
      required: false,
      default: [host: "127.0.0.1", port: 6379],
      doc: """
      Redis client options. See `Redix` docs for more information
      about the options.
      """
    ],
    redis_cluster: [
      type: {:custom, __MODULE__, :validate_non_empty_cluster_opts, [:redis_cluster]},
      required: false,
      doc: """
      Required only when `:mode` is set to `:redis_cluster`. A keyword list of
      options.

      See ["Redis Cluster options"](#module-redis-cluster-options)
      section below.
      """,
      subsection: """
      ### Redis Cluster options

      The available options are:
      """,
      keys: [
        configuration_endpoints: [
          type: {:custom, __MODULE__, :validate_non_empty_cluster_opts, [:redis_cluster]},
          required: true,
          doc: """
          A keyword list of named endpoints where the key is an atom as
          an identifier and the value is another keyword list of options
          (same as `:conn_opts`).

          See ["Redis Cluster"](#module-redis-cluster) for more information.
          """,
          keys: [
            *: [
              type: :keyword_list,
              doc: """
              Same as `:conn_opts`.
              """
            ]
          ]
        ],
        override_master_host: [
          type: :boolean,
          required: false,
          default: false,
          doc: """
          Defines whether the given master host should be overridden with the
          configuration endpoint or not. Defaults to `false`.

          The adapter uses the host returned by the **"CLUSTER SHARDS"**
          (Redis >= 7) or **"CLUSTER SLOTS"** (Redis < 7) command. One may
          consider set it to `true` for tests when using Docker for example,
          or when Redis nodes are behind a load balancer that Redis doesn't
          know the endpoint of. See Redis docs for more information.
          """
        ],
        keyslot: [
          type: {:custom, __MODULE__, :validate_behaviour, [Nebulex.Adapter.Keyslot]},
          required: false,
          default: NebulexRedisAdapter.RedisCluster.Keyslot,
          doc: """
          The module implementing the `Nebulex.Adapter.Keyslot`
          behaviour, which is used to compute the node where the command
          will be applied to.
          """
        ]
      ]
    ],
    client_side_cluster: [
      type: {:custom, __MODULE__, :validate_non_empty_cluster_opts, [:client_side_cluster]},
      required: false,
      doc: """
      Required only when `:mode` is set to `:client_side_cluster`. A keyword
      list of options.

      See ["Client-side Cluster options"](#module-client-side-cluster-options)
      section below.
      """,
      subsection: """
      ### Client-side Cluster options

      The available options are:
      """,
      keys: [
        nodes: [
          type: {:custom, __MODULE__, :validate_non_empty_cluster_opts, [:client_side_cluster]},
          required: true,
          doc: """
          A keyword list of named nodes where the key is an atom as
          an identifier and the value is another keyword list of options
          (same as `:conn_opts`).

          See ["Client-side Cluster"](#module-client-side-cluster)
          for more information.
          """,
          keys: [
            *: [
              type: :keyword_list,
              doc: """
              Same as `:conn_opts`.
              """
            ]
          ]
        ],
        keyslot: [
          type: {:custom, __MODULE__, :validate_behaviour, [Nebulex.Adapter.Keyslot]},
          required: false,
          default: NebulexRedisAdapter.ClientCluster.Keyslot,
          doc: """
          The module implementing the `Nebulex.Adapter.Keyslot`
          behaviour, which is used to compute the node where the command
          will be applied to.
          """
        ]
      ]
    ]
  ]

  # Start options schema
  @start_opts_schema NimbleOptions.new!(start_opts_defs)

  ## API

  # coveralls-ignore-start

  @spec start_options_docs() :: binary()
  def start_options_docs do
    NimbleOptions.docs(@start_opts_schema)
  end

  # coveralls-ignore-stop

  @spec validate_start_opts!(keyword()) :: keyword()
  def validate_start_opts!(opts) do
    start_opts =
      opts
      # Skip validating base Nebulex.Cache options
      |> Keyword.drop([
        :otp_app,
        :adapter,
        :cache,
        :name,
        :telemetry_prefix,
        :telemetry,
        :stats
      ])
      |> validate!(@start_opts_schema)

    Keyword.merge(opts, start_opts)
  end

  @spec validate!(keyword(), NimbleOptions.t()) :: keyword()
  def validate!(opts, schema) do
    opts
    |> NimbleOptions.validate(schema)
    |> format_error()
  end

  defp format_error({:ok, opts}) do
    opts
  end

  defp format_error({:error, %NimbleOptions.ValidationError{message: message}}) do
    raise ArgumentError, message
  end

  @doc false
  def validate_behaviour(module, behaviour) when is_atom(module) and is_atom(behaviour) do
    if behaviour in module_behaviours(module, "module") do
      {:ok, module}
    else
      {:error, "expected #{inspect(module)} to implement the behaviour #{inspect(behaviour)}"}
    end
  end

  @doc false
  def validate_non_empty_cluster_opts(value, mode) do
    if keyword_list?(value) and value != [] do
      {:ok, value}
    else
      {:error, invalid_cluster_config_error(value, mode)}
    end
  end

  @doc false
  def invalid_cluster_config_error(prelude \\ "", value, mode)

  def invalid_cluster_config_error(prelude, value, :redis_cluster) do
    """
    #{prelude}expected non-empty keyword list, got: #{inspect(value)}

            Redis Cluster configuration example:

                config :my_app, MyApp.RedisClusterCache,
                  mode: :redis_cluster,
                  redis_cluster: [
                    configuration_endpoints: [
                      endpoint1_conn_opts: [
                        host: "127.0.0.1",
                        port: 6379,
                        password: "password"
                      ],
                      ...
                    ]
                  ]

            See the documentation for more information.
    """
  end

  def invalid_cluster_config_error(prelude, value, :client_side_cluster) do
    """
    #{prelude}expected non-empty keyword list, got: #{inspect(value)}

            Client-side Cluster configuration example:

                config :my_app, MyApp.ClientSideClusterCache,
                  mode: :client_side_cluster,
                  client_side_cluster: [
                    nodes: [
                      node1: [
                        conn_opts: [
                          host: "127.0.0.1",
                          port: 9001
                        ]
                      ],
                      ...
                    ]
                  ]

            See the documentation for more information.
    """
  end

  defp keyword_list?(value) do
    is_list(value) and Keyword.keyword?(value)
  end
end
