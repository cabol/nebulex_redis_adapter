defmodule NebulexRedisAdapter do
  @moduledoc ~S"""
  Nebulex adapter for Redis. This adapter is implemented using `Redix`,
  a Redis driver for Elixir.

  **NebulexRedisAdapter** provides three setup alternatives:

    * **Standalone** - The adapter establishes a pool of connections
      with a single Redis node. The `:standalone` is the default mode.

    * **Redis Cluster** - [Redis Cluster](https://redis.io/topics/cluster-tutorial)
      is a built-in feature in Redis since version 3, and it may be the most
      convenient and recommendable way to set up Redis in a cluster and have
      a distributed cache storage out-of-box. This adapter provides the
      `:redis_cluster` mode to set up **Redis Cluster** from the client-side
      automatically and be able to use it transparently.

    * **Built-in client-side cluster based on sharding** - This adapter
      provides a simple client-side cluster implementation based on
      Sharding distribution model via `:client_side_cluster` mode.

  ## Shared Options

  In addition to `Nebulex.Cache` shared options, this adapters supports the
  following options:

    * `:mode` - Defines the mode Redis will be set up. It can be one of the
      next values: `:standalone`, `:client_side_cluster`, `:redis_cluster`.
      Defaults to `:standalone`.

    * `:pool_size` - Number of connections in the pool. Defaults to
      `System.schedulers_online()`.

    * `:conn_opts` - Redis client options (`Redix` options in this case).
      For more information about connection options, see `Redix` docs.

  ## Telemetry events

  This adapter emits the recommended Telemetry events.
  See the "Telemetry events" section in `Nebulex.Cache`
  for more information.

  ## TTL or Expiration Time

  As is explained in `Nebulex.Cache`, most of the write-like functions support
  the `:ttl` option to define the expiration time, and it is defined in
  **milliseconds**. Despite Redis work with **seconds**, the conversion logic
  is handled by the adapter transparently, so when using a cache even with the
  Redis adapter, be sure you pass the `:ttl` option in **milliseconds**.

  ## Data Types

  This adapter only works with strings internally, which means the given
  Elixir terms are encoded to binaries before executing the Redis command.
  The encoding/decoding process is performed by the adapter under-the-hood,
  so it is completely transparent for the user.

  **NOTE:** Support for other Redis Data Types is in the roadmap.

  ## Standalone

  We can define a cache to use Redis as follows:

      defmodule MyApp.RedisCache do
        use Nebulex.Cache,
          otp_app: :nebulex,
          adapter: NebulexRedisAdapter
      end

  The configuration for the cache must be in your application environment,
  usually defined in your `config/config.exs`:

      config :my_app, MyApp.RedisCache,
        conn_opts: [
          host: "127.0.0.1",
          port: 6379
        ]

  ## Redis Cluster

  We can define a cache to use Redis Cluster as follows:

      defmodule MyApp.RedisClusterCache do
        use Nebulex.Cache,
          otp_app: :nebulex,
          adapter: NebulexRedisAdapter
      end

  The config:

      config :my_app, MyApp.RedisClusterCache,
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
          # Redix options, except `:host` and `:port`; unless we have a cluster
          # of nodes with the same host and/or port, which doesn't make sense.
        ]

  ### Redis Cluster Options

  In addition to shared options, `:redis_cluster` mode supports the following
  options:

    * `:master_nodes` - The list with the configuration for the Redis cluster
      master nodes. The configuration for each master nodes contains the same
      options as `:conn_opts`. The adapter traverses the list trying to
      establish connection at least with one of them and get the cluster slots
      to finally setup the Redis cluster from client side properly. If one
      fails, the adapter retries with the next in the list, that's why at least
      one master node must be set.

    * `:conn_opts` - Same as shared options (optional). The `:conn_opts` will
      be applied to each connection pool with the cluster (they will override
      the host and port retrieved from cluster slots info). For that reason,
      be careful when setting `:host` or `:port` options since they will be
      used globally and can cause connection issues. Normally, we add here
      the desired client options except `:host` and `:port`. If you have a
      cluster with the same host for all nodes, in that case make sense to
      add also the `:host` option.

    * `:pool_size` - Same as shared options (optional). It applies to all
      cluster slots, meaning all connection pools will have the same size.

  ## Client-side cluster

  We can define a cache with "client-side cluster mode" as follows:

      defmodule MyApp.ClusteredCache do
        use Nebulex.Cache,
          otp_app: :nebulex,
          adapter: NebulexRedisAdapter
      end

  The config:

      config :my_app, MyApp.ClusteredCache,
        mode: :client_side_cluster,
        nodes: [
          node1: [
            pool_size: 10,
            conn_opts: [
              host: "127.0.0.1",
              port: 9001
            ]
          ],
          node2: [
            pool_size: 4,
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

  By default, the adapter uses `NebulexRedisAdapter.ClientCluster.Keyslot` for the
  keyslot. Besides, if `:jchash` is defined as dependency, the adapter will use
  consistent-hashing automatically. However, you can also provide your own
  implementation by implementing the `Nebulex.Adapter.Keyslot` and set it into
  the `:keyslot` option. For example:

      defmodule MyApp.ClusteredCache.Keyslot do
        use Nebulex.Adapter.Keyslot

        @impl true
        def hash_slot(key, range) do
          # your implementation goes here
        end
      end

  And the config:

      config :my_app, MyApp.ClusteredCache,
        mode: :client_side_cluster,
        keyslot: MyApp.ClusteredCache.Keyslot,
        nodes: [
          ...
        ]

  ### Client-side cluster options

  In addition to shared options, `:client_side_cluster` mode supports the following
  options:

    * `:nodes` - The list of nodes the adapter will setup the cluster with;
      a pool of connections is established per node. The `:client_side_cluster` mode
      enables resilience to be able to survive in case any node(s) gets
      unreachable. For each element of the list, we set the configuration
      for each node, such as `:conn_opts`, `:pool_size`, etc.

    * `:keyslot` - Defines the module implementing `Nebulex.Adapter.Keyslot`
      behaviour, used to compute the node where the command will be applied to.
      It is highly recommendable to provide a consistent hashing implementation.

  ## Queryable API

  Since the queryable API is implemented by using `KEYS` command:

    * Only strings (`String.t()`) are allowed as query parameter.
    * Only keys can be queried.

  ### Examples

      iex> MyApp.RedisCache.put_all(%{
      ...>   "firstname" => "Albert",
      ...>   "lastname" => "Einstein",
      ...>   "age" => 76
      ...> })
      :ok

      iex> MyApp.RedisCache.all("**name**")
      ["firstname", "lastname"]

      iex> MyApp.RedisCache.all("a??")
      ["age"]

      iex> MyApp.RedisCache.all()
      ["age", "firstname", "lastname"]

      iex> stream = TestCache.stream("**name**")
      iex> stream |> Enum.to_list()
      ["firstname", "lastname"]

      # get the values for the returned queried keys
      iex> "**name**" |> MyApp.RedisCache.all() |> MyApp.RedisCache.get_all()
      %{"firstname" => "Albert", "lastname" => "Einstein"}

  ## Using the cache for executing a Redis command or pipeline

  Since `NebulexRedisAdapter` works on top of `Redix` and provides features like
  connection pools and "Redis Cluster" support, it may be seen also as a sort of
  Redis client, but it is meant to be used mainly with the Nebulex cache API.
  However, Redis API is quite extensive and there are a lot of useful commands
  we may want to run taking advantage of the `NebulexRedisAdapter` features.
  Therefore, the adapter injects two additional/extended functions to the
  defined cache: `command!/3` and `pipeline!/3`.

  ### `command!(key \\ nil, name \\ __MODULE__, command)`

      iex> MyCache.command!("mylist", ["LPUSH", "mylist", "world"])
      1
      iex> MyCache.command!("mylist", ["LPUSH", "mylist", "hello"])
      2
      iex> MyCache.command!("mylist", ["LRANGE", "mylist", "0", "-1"])
      ["hello", "world"]

  ### `pipeline!(key \\ nil, name \\ __MODULE__, commands)`

      iex> cache.pipeline!("mylist", [
      ...>   ["LPUSH", "mylist", "world"],
      ...>   ["LPUSH", "mylist", "hello"],
      ...>   ["LRANGE", "mylist", "0", "-1"]
      ...> ])
      [1, 2, ["hello", "world"]]

  Arguments for `command!/3` and `pipeline!/3`:

    * `key` - it is required when used the adapter in mode `:redis_cluster`
      or `:client_side_cluster` so that the node where the commands will
      take place can be selected properly. For `:standalone` it is optional.
    * `name` - The name of the cache in case you are using dynamic caches,
      otherwise it is not required.
    * `commands` - Redis commands.

  ## Transactions

  This adapter doesn't provide support for transactions, since there is no way
  to guarantee its execution on Redis itself, at least not in the way the
  `c:Nebulex.Adapter.Transaction.transaction/3` works, because the anonymous
  function can have any kind of logic, which cannot be translated easily into
  Redis commands.

  > In the future, it is planned to add to Nebulex a `multi`-like function to
    perform multiple commands at once, perhaps that will be the best way to
    perform [transactions via Redis](https://redis.io/topics/transactions).

  """

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Entry
  @behaviour Nebulex.Adapter.Queryable

  import Nebulex.Adapter
  import Nebulex.Helpers
  import NebulexRedisAdapter.Encoder

  use Nebulex.Adapter.Stats

  alias Nebulex.Adapter
  alias Nebulex.Adapter.Stats
  alias Nebulex.Telemetry
  alias Nebulex.Telemetry.StatsHandler
  alias NebulexRedisAdapter.{ClientCluster, Command, Connection, RedisCluster}

  ## Nebulex.Adapter

  @impl true
  defmacro __before_compile__(_env) do
    quote do
      @doc """
      A convenience function for executing a Redis command.
      """
      def command!(key \\ nil, name \\ __MODULE__, command) do
        Adapter.with_meta(name, fn _, meta ->
          Command.exec!(meta, command, key)
        end)
      end

      @doc """
      A convenience function for executing a Redis pipeline.
      """
      def pipeline!(key \\ nil, name \\ __MODULE__, commands) do
        Adapter.with_meta(name, fn _, meta ->
          Command.pipeline!(meta, commands, key)
        end)
      end
    end
  end

  @impl true
  def init(opts) do
    # required cache name
    name = opts[:name] || Keyword.fetch!(opts, :cache)

    # adapter mode
    mode = Keyword.get(opts, :mode, :standalone)

    # pool size
    pool_size =
      get_option(
        opts,
        :pool_size,
        "an integer > 0",
        &(is_integer(&1) and &1 > 0),
        System.schedulers_online()
      )

    # init the specs according to the adapter mode
    {children, default_keyslot} = do_init(mode, name, pool_size, opts)

    # keyslot module for selecting nodes
    keyslot =
      opts
      |> Keyword.get(:keyslot, default_keyslot)
      |> assert_behaviour(Nebulex.Adapter.Keyslot, "keyslot")

    # cluster nodes
    nodes =
      for {node_name, node_opts} <- Keyword.get(opts, :nodes, []) do
        {node_name, Keyword.get(node_opts, :pool_size, System.schedulers_online())}
      end

    child_spec =
      Nebulex.Adapters.Supervisor.child_spec(
        name: normalize_module_name([name, Supervisor]),
        strategy: :rest_for_one,
        children: children
      )

    stats_counter = Stats.init(opts)

    meta = %{
      name: name,
      mode: mode,
      keyslot: keyslot,
      nodes: nodes,
      pool_size: pool_size,
      stats_counter: stats_counter,
      started_at: DateTime.utc_now(),
      default_dt: Keyword.get(opts, :default_data_type, :object),
      telemetry: Keyword.fetch!(opts, :telemetry),
      telemetry_prefix: Keyword.fetch!(opts, :telemetry_prefix)
    }

    Telemetry.attach_many(
      stats_counter,
      [meta.telemetry_prefix ++ [:command, :stop]],
      &StatsHandler.handle_event/4,
      stats_counter
    )

    {:ok, child_spec, meta}
  end

  defp do_init(:standalone, name, pool_size, opts) do
    {:ok, children} = Connection.init(name, pool_size, opts)
    {children, ClientCluster.Keyslot}
  end

  defp do_init(:client_side_cluster, _name, _pool_size, opts) do
    {:ok, children} = ClientCluster.init(opts)
    {children, ClientCluster.Keyslot}
  end

  defp do_init(:redis_cluster, name, pool_size, opts) do
    {:ok, children} = RedisCluster.init(name, pool_size, opts)
    {children, RedisCluster.Keyslot}
  end

  ## Nebulex.Adapter.Entry

  @impl true
  defspan get(adapter_meta, key, _opts) do
    with_pipeline(adapter_meta, key, [["GET", encode(key)]])
  end

  @impl true
  defspan get_all(adapter_meta, keys, _opts) do
    do_get_all(adapter_meta, keys)
  end

  defp do_get_all(%{mode: :standalone} = adapter_meta, keys) do
    mget(nil, adapter_meta, keys)
  end

  defp do_get_all(adapter_meta, keys) do
    keys
    |> group_keys_by_hash_slot(adapter_meta)
    |> Enum.reduce(%{}, fn {hash_slot, keys}, acc ->
      return = mget(hash_slot, adapter_meta, keys)
      Map.merge(acc, return)
    end)
  end

  defp mget(hash_slot_key, adapter_meta, keys) do
    adapter_meta
    |> Command.exec!(["MGET" | for(k <- keys, do: encode(k))], hash_slot_key)
    |> Enum.reduce({keys, %{}}, fn
      nil, {[_key | keys], acc} ->
        {keys, acc}

      value, {[key | keys], acc} ->
        {keys, Map.put(acc, key, decode(value))}
    end)
    |> elem(1)
  end

  @impl true
  defspan put(adapter_meta, key, value, ttl, on_write, opts) do
    cmd_opts = cmd_opts(action: on_write, ttl: fix_ttl(ttl))
    redis_k = encode(key)
    redis_v = encode(value, opts)

    case Command.exec!(adapter_meta, ["SET", redis_k, redis_v | cmd_opts], key) do
      "OK" -> true
      nil -> false
    end
  end

  @impl true
  defspan put_all(adapter_meta, entries, ttl, on_write, opts) do
    ttl = fix_ttl(ttl)

    case adapter_meta.mode do
      :standalone ->
        do_put_all(adapter_meta, nil, entries, ttl, on_write, opts)

      _ ->
        entries
        |> group_keys_by_hash_slot(adapter_meta)
        |> Enum.reduce(:ok, fn {hash_slot, group}, acc ->
          acc && do_put_all(adapter_meta, hash_slot, group, ttl, on_write, opts)
        end)
    end
  end

  defp do_put_all(adapter_meta, hash_slot, entries, ttl, on_write, opts) do
    cmd =
      case on_write do
        :put -> "MSET"
        :put_new -> "MSETNX"
      end

    {mset, expire} =
      Enum.reduce(entries, {[cmd], []}, fn {key, val}, {acc1, acc2} ->
        redis_k = encode(key)

        acc2 =
          if is_integer(ttl),
            do: [["EXPIRE", redis_k, ttl] | acc2],
            else: acc2

        {[encode(val, opts), redis_k | acc1], acc2}
      end)

    adapter_meta
    |> Command.pipeline!([Enum.reverse(mset) | expire], hash_slot)
    |> hd()
    |> case do
      "OK" -> :ok
      1 -> true
      0 -> false
    end
  end

  @impl true
  defspan delete(adapter_meta, key, _opts) do
    _ = Command.exec!(adapter_meta, ["DEL", encode(key)], key)
    :ok
  end

  @impl true
  defspan take(adapter_meta, key, _opts) do
    redis_k = encode(key)
    with_pipeline(adapter_meta, key, [["GET", redis_k], ["DEL", redis_k]])
  end

  @impl true
  defspan has_key?(adapter_meta, key) do
    case Command.exec!(adapter_meta, ["EXISTS", encode(key)], key) do
      1 -> true
      0 -> false
    end
  end

  @impl true
  defspan ttl(adapter_meta, key) do
    case Command.exec!(adapter_meta, ["TTL", encode(key)], key) do
      -1 -> :infinity
      -2 -> nil
      ttl -> ttl * 1000
    end
  end

  @impl true
  defspan expire(adapter_meta, key, ttl) do
    do_expire(adapter_meta, key, ttl)
  end

  defp do_expire(adapter_meta, key, :infinity) do
    redis_k = encode(key)

    case Command.pipeline!(adapter_meta, [["TTL", redis_k], ["PERSIST", redis_k]], key) do
      [-2, 0] -> false
      [_, _] -> true
    end
  end

  defp do_expire(adapter_meta, key, ttl) do
    case Command.exec!(adapter_meta, ["EXPIRE", encode(key), fix_ttl(ttl)], key) do
      1 -> true
      0 -> false
    end
  end

  @impl true
  defspan touch(adapter_meta, key) do
    case Command.exec!(adapter_meta, ["TOUCH", encode(key)], key) do
      1 -> true
      0 -> false
    end
  end

  @impl true
  defspan update_counter(adapter_meta, key, incr, ttl, default, _opts) do
    do_update_counter(adapter_meta, key, incr, ttl, default)
  end

  defp do_update_counter(adapter_meta, key, incr, :infinity, default) do
    redis_k = encode(key)

    adapter_meta
    |> maybe_incr_default(key, redis_k, default)
    |> Command.exec!(["INCRBY", redis_k, incr], key)
  end

  defp do_update_counter(adapter_meta, key, incr, ttl, default) do
    redis_k = encode(key)

    adapter_meta
    |> maybe_incr_default(key, redis_k, default)
    |> Command.pipeline!([["INCRBY", redis_k, incr], ["EXPIRE", redis_k, fix_ttl(ttl)]], key)
    |> hd()
  end

  defp maybe_incr_default(adapter_meta, key, redis_k, default)
       when is_integer(default) and default > 0 do
    case Command.exec!(adapter_meta, ["EXISTS", redis_k], key) do
      1 ->
        adapter_meta

      0 ->
        _ = Command.exec!(adapter_meta, ["INCRBY", redis_k, default], key)
        adapter_meta
    end
  end

  defp maybe_incr_default(adapter_meta, _, _, _), do: adapter_meta

  ## Nebulex.Adapter.Queryable

  @impl true
  defspan execute(adapter_meta, operation, query, _opts) do
    do_execute(adapter_meta, operation, query)
  end

  defp do_execute(%{mode: mode} = adapter_meta, :count_all, nil) do
    exec!(mode, [adapter_meta, ["DBSIZE"]], [0, &Kernel.+(&2, &1)])
  end

  defp do_execute(%{mode: mode} = adapter_meta, :delete_all, nil) do
    size = exec!(mode, [adapter_meta, ["DBSIZE"]], [0, &Kernel.+(&2, &1)])
    _ = exec!(mode, [adapter_meta, ["FLUSHDB"]], [])
    size
  end

  defp do_execute(adapter_meta, :all, query) do
    execute_query(query, adapter_meta)
  end

  @impl true
  defspan stream(adapter_meta, query, _opts) do
    Stream.resource(
      fn ->
        execute_query(query, adapter_meta)
      end,
      fn
        [] -> {:halt, []}
        elems -> {elems, []}
      end,
      & &1
    )
  end

  @impl Nebulex.Adapter.Stats
  def stats(%{started_at: started_at} = adapter_meta) do
    if stats = super(adapter_meta) do
      %{stats | metadata: Map.put(stats.metadata, :started_at, started_at)}
    end
  end

  ## Private Functions

  defp with_pipeline(adapter_meta, key, pipeline) do
    adapter_meta
    |> Command.pipeline!(pipeline, key)
    |> hd()
    |> decode()
  end

  defp cmd_opts(keys), do: Enum.reduce(keys, [], &cmd_opts/2)

  defp cmd_opts({:action, :put}, acc), do: acc
  defp cmd_opts({:action, :put_new}, acc), do: ["NX" | acc]
  defp cmd_opts({:action, :replace}, acc), do: ["XX" | acc]
  defp cmd_opts({:ttl, :infinity}, acc), do: acc
  defp cmd_opts({:ttl, ttl}, acc), do: ["EX", "#{ttl}" | acc]

  defp fix_ttl(:infinity), do: :infinity
  defp fix_ttl(ttl) when is_integer(ttl) and ttl >= 1000, do: div(ttl, 1000)

  defp fix_ttl(ttl) do
    raise ArgumentError,
          "expected ttl: to be an integer >= 1000 or :infinity, got: #{inspect(ttl)}"
  end

  defp execute_query(nil, adapter_meta) do
    for key <- execute_query("*", adapter_meta), do: decode(key)
  end

  defp execute_query(pattern, %{mode: mode} = adapter_meta) when is_binary(pattern) do
    exec!(mode, [adapter_meta, ["KEYS", pattern]], [[], &Kernel.++(&1, &2)])
  end

  defp execute_query(pattern, _adapter_meta) do
    raise Nebulex.QueryError, message: "invalid pattern", query: pattern
  end

  defp exec!(:standalone, args, _extra_args) do
    apply(Command, :exec!, args)
  end

  defp exec!(:client_side_cluster, args, extra_args) do
    apply(ClientCluster, :exec!, args ++ extra_args)
  end

  defp exec!(:redis_cluster, args, extra_args) do
    apply(RedisCluster, :exec!, args ++ extra_args)
  end

  defp group_keys_by_hash_slot(enum, %{mode: :client_side_cluster, nodes: nodes, keyslot: keyslot}) do
    ClientCluster.group_keys_by_hash_slot(enum, nodes, keyslot)
  end

  defp group_keys_by_hash_slot(enum, %{mode: :redis_cluster, keyslot: keyslot}) do
    RedisCluster.group_keys_by_hash_slot(enum, keyslot)
  end
end
