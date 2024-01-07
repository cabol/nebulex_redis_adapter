defmodule NebulexRedisAdapter do
  @moduledoc """
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
        redis_cluster: [
          configuration_endpoints: [
            endpoint1_conn_opts: [
              host: "127.0.0.1",
              port: 6379,
              # Add the password if 'requirepass' is on
              password: "password"
            ],
            ...
          ]
        ]

  ## Client-side Cluster

  We can define a cache with "client-side cluster mode" as follows:

      defmodule MyApp.ClusteredCache do
        use Nebulex.Cache,
          otp_app: :nebulex,
          adapter: NebulexRedisAdapter
      end

  The config:

      config :my_app, MyApp.ClusteredCache,
        mode: :client_side_cluster,
        client_side_cluster: [
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
            ],
            ...
          ]
        ]

  ## Configuration options

  In addition to `Nebulex.Cache` config options, the adapter supports the
  following options:

  #{NebulexRedisAdapter.Options.start_options_docs()}

  ## Shared runtime options

  Since the adapter runs on top of `Redix`, all commands accept their options
  (e.g.: `:timeout`, and `:telemetry_metadata`). See `Redix` docs for more
  information.

  ### Redis Cluster runtime options

  The following options apply to all commands:

    * `:lock_retries` - This option is specific to the `:redis_cluster` mode.
      When the config manager is running and setting up the hash slot map,
      all Redis commands get blocked until the cluster is properly configured
      and the hash slot map is ready to use. This option defines the max retry
      attempts to acquire the lock and execute the command in case the
      configuration manager is running and all commands are locked.
      Defaults to `:infinity`.

  ## Custom Keyslot

  As it is mentioned in the configuration options above, the `:redis_cluster`
  and `:client_side_cluster` modes have a default value for the `:keyslot`
  option. However, you can also provide your own implementation by implementing
  the `Nebulex.Adapter.Keyslot` and configuring the `:keyslot` option.
  For example:

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
        client_side_cluster: [
          keyslot: MyApp.ClusteredCache.Keyslot,
          nodes: [
            ...
          ]
        ]

  > **NOTE:** For `:redis_cluster` mode, the`:keyslot` implementation must
    follow the [Redis cluster specification][redis_cluster_spec].

  [redis_cluster_spec]: https://redis.io/docs/reference/cluster-spec/

  ## TTL or Expiration Time

  As is explained in `Nebulex.Cache`, most of the write-like functions support
  the `:ttl` option to define the expiration time, and it is defined in
  **milliseconds**. Despite Redis work with **seconds**, the conversion logic
  is handled by the adapter transparently, so when using a cache even with the
  Redis adapter, be sure you pass the `:ttl` option in **milliseconds**.

  ## Data Types

  Currently. the adapter only works with strings, which means a given Elixir
  term is encoded to a binary/string before executing a command. Similarly,
  a returned binary from Redis after executing a command is decoded into an
  Elixir term. The encoding/decoding process is performed by the adapter
  under-the-hood. However, it is possible to provide a custom serializer via the
  option `:serializer`. The value must be module implementing the
  `NebulexRedisAdapter.Serializer` behaviour.

  **NOTE:** Support for other Redis Data Types is in the roadmap.

  ## Queryable API

  Since the queryable API is implemented by using `KEYS` command,
  keep in mind the following caveats:

    * Only keys can be queried.
    * Only strings and predefined queries are allowed as query values.

  ### Predefined queries

    * `nil` - All keys are returned.

    * `{:in, [term]}` - Only the keys in the given key list (`[term]`)
      are returned. This predefined query is only supported for
      `c:Nebulex.Cache.delete_all/2`. This is the recommended
      way of doing bulk delete of keys.

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

      iex> stream = MyApp.RedisCache.stream("**name**")
      iex> stream |> Enum.to_list()
      ["firstname", "lastname"]

      # get the values for the returned queried keys
      iex> "**name**" |> MyApp.RedisCache.all() |> MyApp.RedisCache.get_all()
      %{"firstname" => "Albert", "lastname" => "Einstein"}

  ### Deleting multiple keys at once (bulk delete)

      iex> MyApp.RedisCache.delete_all({:in, ["foo", "bar"]})
      2

  ## Transactions

  This adapter doesn't provide support for transactions. However, in the future,
  it is planned support [Redis Transactions][redis_transactions] by using the
  commands `MULTI`, `EXEC`, `DISCARD` and `WATCH`.

  [redis_transactions]: https://redis.io/docs/manual/transactions/

  ## Running Redis commands and/or pipelines

  Since `NebulexRedisAdapter` works on top of `Redix` and provides features like
  connection pools and "Redis Cluster" support, it may be seen also as a sort of
  Redis client, but it is meant to be used mainly with the Nebulex cache API.
  However, Redis API is quite extensive and there are a lot of useful commands
  we may want to run taking advantage of the `NebulexRedisAdapter` features.
  Therefore, the adapter provides two additional/extended functions to the
  defined cache: `command!/2` and `pipeline!/2`.

  ### `command!(command, opts \\\\ [])`

      iex> MyCache.command!(["LPUSH", "mylist", "world"], key: "mylist")
      1
      iex> MyCache.command!(["LPUSH", "mylist", "hello"], key: "mylist")
      2
      iex> MyCache.command!(["LRANGE", "mylist", "0", "-1"], key: "mylist")
      ["hello", "world"]

  ### `pipeline!(commands, opts \\\\ [])`

      iex> [
      ...>   ["LPUSH", "mylist", "world"],
      ...>   ["LPUSH", "mylist", "hello"],
      ...>   ["LRANGE", "mylist", "0", "-1"]
      ...> ]
      ...> |> cache.pipeline!(key: "mylist")
      [1, 2, ["hello", "world"]]

  ### Options for `command!/2` and `pipeline!/2`:

    * `:key` - It is required when used the adapter in mode `:redis_cluster`
      or `:client_side_cluster` so that the node where the commands will
      take place can be selected properly. For `:standalone` mode is not
      required (optional).
    * `:name` - The name of the cache in case you are using dynamic caches,
      otherwise it is not required.

  Since these functions run on top of `Redix`, they also accept their options
  (e.g.: `:timeout`, and `:telemetry_metadata`). See `Redix` docs for more
  information.

  ## Telemetry

  This adapter emits the recommended Telemetry events.
  See the "Telemetry events" section in `Nebulex.Cache`
  for more information.

  ### Adapter-specific telemetry events for the `:redis_cluster` mode

  Aside from the recommended Telemetry events by `Nebulex.Cache`, this adapter
  exposes the following Telemetry events for the `:redis_cluster` mode:

    * `telemetry_prefix ++ [:config_manager, :setup, :start]` - This event is
      specific to the `:redis_cluster` mode. Before the configuration manager
      calls Redis to set up the cluster shards, this event should be invoked.

      The `:measurements` map will include the following:

      * `:system_time` - The current system time in native units from calling:
        `System.system_time()`.

      A Telemetry `:metadata` map including the following fields:

      * `:adapter_meta` - The adapter metadata.
      * `:pid` - The configuration manager PID.

    * `telemetry_prefix ++ [:config_manager, :setup, :stop]` - This event is
      specific to the `:redis_cluster` mode. After the configuration manager
      set up the cluster shards, this event should be invoked.

      The `:measurements` map will include the following:

      * `:duration` - The time spent configuring the cluster. The measurement
        is given in the `:native` time unit. You can read more about it in the
        docs for `System.convert_time_unit/3`.

      A Telemetry `:metadata` map including the following fields:

      * `:adapter_meta` - The adapter metadata.
      * `:pid` - The configuration manager PID.
      * `:status` - The cluster setup status. If the cluster was configured
        successfully, the status will be set to `:ok`, otherwise, will be
        set to `:error`.
      * `:error` - The status reason. When the status is `:ok`, the reason is
        `:succeeded`, otherwise, it is the error reason.

    * `telemetry_prefix ++ [:config_manager, :setup, :exception]` - This event
      is specific to the `:redis_cluster` mode. When an exception is raised
      while configuring the cluster, this event should be invoked.

      The `:measurements` map will include the following:

      * `:duration` - The time spent configuring the cluster. The measurement
        is given in the `:native` time unit. You can read more about it in the
        docs for `System.convert_time_unit/3`.

      A Telemetry `:metadata` map including the following fields:

      * `:adapter_meta` - The adapter metadata.
      * `:pid` - The configuration manager PID.
      * `:kind` - The type of the error: `:error`, `:exit`, or `:throw`.
      * `:reason` - The reason of the error.
      * `:stacktrace` - The stacktrace.

  """

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Entry
  @behaviour Nebulex.Adapter.Queryable

  # Inherit default stats implementation
  use Nebulex.Adapter.Stats

  # Inherit default serializer implementation
  use NebulexRedisAdapter.Serializer

  import Nebulex.Adapter
  import Nebulex.Helpers

  alias Nebulex.Adapter
  alias Nebulex.Adapter.Stats

  alias NebulexRedisAdapter.{
    ClientCluster,
    Command,
    Connection,
    Options,
    RedisCluster
  }

  ## Nebulex.Adapter

  @impl true
  defmacro __before_compile__(_env) do
    quote do
      @doc """
      A convenience function for executing a Redis command.
      """
      def command(command, opts \\ []) do
        {name, key, opts} = pop_cache_name_and_key(opts)

        Adapter.with_meta(name, fn _, meta ->
          Command.exec(meta, command, key, opts)
        end)
      end

      @doc """
      A convenience function for executing a Redis command,
      but raises an exception if an error occurs.
      """
      def command!(command, opts \\ []) do
        {name, key, opts} = pop_cache_name_and_key(opts)

        Adapter.with_meta(name, fn _, meta ->
          Command.exec!(meta, command, key, opts)
        end)
      end

      @doc """
      A convenience function for executing a Redis pipeline.
      """
      def pipeline(commands, opts \\ []) do
        {name, key, opts} = pop_cache_name_and_key(opts)

        Adapter.with_meta(name, fn _, meta ->
          Command.pipeline(meta, commands, key, opts)
        end)
      end

      @doc """
      A convenience function for executing a Redis pipeline,
      but raises an exception if an error occurs.
      """
      def pipeline!(commands, opts \\ []) do
        {name, key, opts} = pop_cache_name_and_key(opts)

        Adapter.with_meta(name, fn _, meta ->
          Command.pipeline!(meta, commands, key, opts)
        end)
      end

      defp pop_cache_name_and_key(opts) do
        {name, opts} = Keyword.pop(opts, :name, __MODULE__)
        {key, opts} = Keyword.pop(opts, :key)

        {name, key, opts}
      end
    end
  end

  @impl true
  def init(opts) do
    # Required cache name
    name = opts[:name] || Keyword.fetch!(opts, :cache)

    # Init stats
    stats_counter = Stats.init(opts)

    # Validate options
    opts = Options.validate_start_opts!(opts)

    # Adapter mode
    mode = Keyword.fetch!(opts, :mode)

    # Local registry
    registry = normalize_module_name([name, Registry])

    # Redis serializer for encoding/decoding keys and values
    serializer_meta = assert_serializer!(opts)

    # Resolve the pool size
    pool_size = Keyword.get_lazy(opts, :pool_size, fn -> System.schedulers_online() end)

    # Init adapter metadata
    adapter_meta =
      %{
        cache_pid: self(),
        name: name,
        mode: mode,
        pool_size: pool_size,
        stats_counter: stats_counter,
        registry: registry,
        started_at: DateTime.utc_now(),
        default_dt: Keyword.get(opts, :default_data_type, :object),
        telemetry: Keyword.fetch!(opts, :telemetry),
        telemetry_prefix: Keyword.fetch!(opts, :telemetry_prefix)
      }
      |> Map.merge(serializer_meta)

    # Init the connections child spec according to the adapter mode
    {conn_child_spec, adapter_meta} = do_init(adapter_meta, opts)

    # Build the child spec
    child_spec =
      Nebulex.Adapters.Supervisor.child_spec(
        name: normalize_module_name([name, Supervisor]),
        strategy: :one_for_all,
        children: [
          {NebulexRedisAdapter.BootstrapServer, adapter_meta},
          {Registry, name: registry, keys: :unique},
          conn_child_spec
        ]
      )

    {:ok, child_spec, adapter_meta}
  end

  defp assert_serializer!(opts) do
    serializer = Keyword.get(opts, :serializer, __MODULE__)
    serializer_opts = Keyword.fetch!(opts, :serializer_opts)

    %{
      serializer: serializer,
      encode_key_opts: Keyword.fetch!(serializer_opts, :encode_key),
      encode_value_opts: Keyword.fetch!(serializer_opts, :encode_value),
      decode_key_opts: Keyword.fetch!(serializer_opts, :decode_key),
      decode_value_opts: Keyword.fetch!(serializer_opts, :decode_value)
    }
  end

  defp do_init(%{mode: :standalone} = adapter_meta, opts) do
    Connection.init(adapter_meta, opts)
  end

  defp do_init(%{mode: :redis_cluster} = adapter_meta, opts) do
    RedisCluster.init(adapter_meta, opts)
  end

  defp do_init(%{mode: :client_side_cluster} = adapter_meta, opts) do
    ClientCluster.init(adapter_meta, opts)
  end

  ## Nebulex.Adapter.Entry

  @impl true
  defspan get(adapter_meta, key, opts) do
    %{
      serializer: serializer,
      encode_key_opts: enc_key_opts,
      decode_value_opts: dec_value_opts
    } = adapter_meta

    adapter_meta
    |> Command.exec!(["GET", serializer.encode_key(key, enc_key_opts)], key, opts)
    |> serializer.decode_value(dec_value_opts)
  end

  @impl true
  defspan get_all(adapter_meta, keys, opts) do
    do_get_all(adapter_meta, keys, opts)
  end

  defp do_get_all(%{mode: :standalone} = adapter_meta, keys, opts) do
    mget(nil, adapter_meta, keys, opts)
  end

  defp do_get_all(adapter_meta, keys, opts) do
    keys
    |> group_keys_by_hash_slot(adapter_meta, :keys)
    |> Enum.reduce(%{}, fn {hash_slot, keys}, acc ->
      return = mget(hash_slot, adapter_meta, keys, opts)

      Map.merge(acc, return)
    end)
  end

  defp mget(
         hash_slot_key,
         %{
           serializer: serializer,
           encode_key_opts: enc_key_opts,
           decode_value_opts: dec_value_opts
         } = adapter_meta,
         keys,
         opts
       ) do
    adapter_meta
    |> Command.exec!(
      ["MGET" | Enum.map(keys, &serializer.encode_key(&1, enc_key_opts))],
      hash_slot_key,
      opts
    )
    |> Enum.reduce({keys, %{}}, fn
      nil, {[_key | keys], acc} ->
        {keys, acc}

      value, {[key | keys], acc} ->
        {keys, Map.put(acc, key, serializer.decode_value(value, dec_value_opts))}
    end)
    |> elem(1)
  end

  @impl true
  defspan put(adapter_meta, key, value, ttl, on_write, opts) do
    %{
      serializer: serializer,
      encode_key_opts: enc_key_opts,
      encode_value_opts: enc_value_opts
    } = adapter_meta

    redis_k = serializer.encode_key(key, enc_key_opts)
    redis_v = serializer.encode_value(value, enc_value_opts)
    cmd_opts = cmd_opts(action: on_write, ttl: fix_ttl(ttl))

    case Command.exec!(adapter_meta, ["SET", redis_k, redis_v | cmd_opts], key, opts) do
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
        |> group_keys_by_hash_slot(adapter_meta, :tuples)
        |> Enum.reduce(:ok, fn {hash_slot, group}, acc ->
          acc && do_put_all(adapter_meta, hash_slot, group, ttl, on_write, opts)
        end)
    end
  end

  defp do_put_all(
         %{
           serializer: serializer,
           encode_key_opts: enc_key_opts,
           encode_value_opts: enc_value_opts
         } = adapter_meta,
         hash_slot,
         entries,
         ttl,
         on_write,
         opts
       ) do
    cmd =
      case on_write do
        :put -> "MSET"
        :put_new -> "MSETNX"
      end

    {mset, expire} =
      Enum.reduce(entries, {[cmd], []}, fn {key, val}, {acc1, acc2} ->
        redis_k = serializer.encode_key(key, enc_key_opts)

        acc2 =
          if is_integer(ttl),
            do: [["EXPIRE", redis_k, ttl] | acc2],
            else: acc2

        {[serializer.encode_value(val, enc_value_opts), redis_k | acc1], acc2}
      end)

    adapter_meta
    |> Command.pipeline!([Enum.reverse(mset) | expire], hash_slot, opts)
    |> hd()
    |> case do
      "OK" -> :ok
      1 -> true
      0 -> false
    end
  end

  @impl true
  defspan delete(adapter_meta, key, opts) do
    _ = Command.exec!(adapter_meta, ["DEL", enc_key(adapter_meta, key)], key, opts)

    :ok
  end

  @impl true
  defspan take(adapter_meta, key, opts) do
    redis_k = enc_key(adapter_meta, key)

    with_pipeline(adapter_meta, key, [["GET", redis_k], ["DEL", redis_k]], opts)
  end

  @impl true
  defspan has_key?(adapter_meta, key) do
    case Command.exec!(adapter_meta, ["EXISTS", enc_key(adapter_meta, key)], key) do
      1 -> true
      0 -> false
    end
  end

  @impl true
  defspan ttl(adapter_meta, key) do
    case Command.exec!(adapter_meta, ["TTL", enc_key(adapter_meta, key)], key) do
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
    redis_k = enc_key(adapter_meta, key)

    case Command.pipeline!(adapter_meta, [["TTL", redis_k], ["PERSIST", redis_k]], key) do
      [-2, 0] -> false
      [_, _] -> true
    end
  end

  defp do_expire(adapter_meta, key, ttl) do
    redis_k = enc_key(adapter_meta, key)

    case Command.exec!(adapter_meta, ["EXPIRE", redis_k, fix_ttl(ttl)], key) do
      1 -> true
      0 -> false
    end
  end

  @impl true
  defspan touch(adapter_meta, key) do
    redis_k = enc_key(adapter_meta, key)

    case Command.exec!(adapter_meta, ["TOUCH", redis_k], key) do
      1 -> true
      0 -> false
    end
  end

  @impl true
  defspan update_counter(adapter_meta, key, incr, ttl, default, opts) do
    do_update_counter(adapter_meta, key, incr, ttl, default, opts)
  end

  defp do_update_counter(adapter_meta, key, incr, :infinity, default, opts) do
    redis_k = enc_key(adapter_meta, key)

    adapter_meta
    |> maybe_incr_default(key, redis_k, default, opts)
    |> Command.exec!(["INCRBY", redis_k, incr], key, opts)
  end

  defp do_update_counter(adapter_meta, key, incr, ttl, default, opts) do
    redis_k = enc_key(adapter_meta, key)

    adapter_meta
    |> maybe_incr_default(key, redis_k, default, opts)
    |> Command.pipeline!(
      [["INCRBY", redis_k, incr], ["EXPIRE", redis_k, fix_ttl(ttl)]],
      key,
      opts
    )
    |> hd()
  end

  defp maybe_incr_default(adapter_meta, key, redis_k, default, opts)
       when is_integer(default) and default > 0 do
    case Command.exec!(adapter_meta, ["EXISTS", redis_k], key, opts) do
      1 ->
        adapter_meta

      0 ->
        _ = Command.exec!(adapter_meta, ["INCRBY", redis_k, default], key, opts)

        adapter_meta
    end
  end

  defp maybe_incr_default(adapter_meta, _, _, _, _) do
    adapter_meta
  end

  ## Nebulex.Adapter.Queryable

  @impl true
  defspan execute(adapter_meta, operation, query, opts) do
    do_execute(adapter_meta, operation, query, opts)
  end

  defp do_execute(%{mode: mode} = adapter_meta, :count_all, nil, opts) do
    exec!(mode, [adapter_meta, ["DBSIZE"], opts], [0, &Kernel.+(&2, &1)])
  end

  defp do_execute(%{mode: mode} = adapter_meta, :delete_all, nil, opts) do
    size = exec!(mode, [adapter_meta, ["DBSIZE"], opts], [0, &Kernel.+(&2, &1)])
    _ = exec!(mode, [adapter_meta, ["FLUSHDB"], opts], [])

    size
  end

  defp do_execute(%{mode: :standalone} = adapter_meta, :delete_all, {:in, keys}, opts)
       when is_list(keys) do
    _ = Command.exec!(adapter_meta, ["DEL" | Enum.map(keys, &enc_key(adapter_meta, &1))], opts)

    length(keys)
  end

  defp do_execute(adapter_meta, :delete_all, {:in, keys}, opts)
       when is_list(keys) do
    :ok =
      keys
      |> group_keys_by_hash_slot(adapter_meta, :keys)
      |> Enum.each(fn {hash_slot, keys_group} ->
        Command.exec!(
          adapter_meta,
          ["DEL" | Enum.map(keys_group, &enc_key(adapter_meta, &1))],
          hash_slot,
          opts
        )
      end)

    length(keys)
  end

  defp do_execute(adapter_meta, :all, query, opts) do
    execute_query(query, adapter_meta, opts)
  end

  @impl true
  defspan stream(adapter_meta, query, opts) do
    Stream.resource(
      fn ->
        execute_query(query, adapter_meta, opts)
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

  defp with_pipeline(
         %{serializer: serializer, decode_value_opts: dec_val_opts} = adapter_meta,
         key,
         pipeline,
         opts
       ) do
    adapter_meta
    |> Command.pipeline!(pipeline, key, opts)
    |> hd()
    |> serializer.decode_value(dec_val_opts)
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

  defp execute_query(nil, %{serializer: serializer} = adapter_meta, opts) do
    "*"
    |> execute_query(adapter_meta, opts)
    |> Enum.map(&serializer.decode_key/1)
  end

  defp execute_query(pattern, %{mode: mode} = adapter_meta, opts) when is_binary(pattern) do
    exec!(mode, [adapter_meta, ["KEYS", pattern], opts], [[], &Kernel.++(&1, &2)])
  end

  defp execute_query(pattern, _adapter_meta, _opts) do
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

  defp group_keys_by_hash_slot(
         enum,
         %{
           mode: :client_side_cluster,
           nodes: nodes,
           keyslot: keyslot
         },
         enum_type
       ) do
    ClientCluster.group_keys_by_hash_slot(enum, nodes, keyslot, enum_type)
  end

  defp group_keys_by_hash_slot(enum, %{mode: :redis_cluster, keyslot: keyslot}, enum_type) do
    RedisCluster.group_keys_by_hash_slot(enum, keyslot, enum_type)
  end

  defp enc_key(%{serializer: serializer, encode_key_opts: enc_key_opts}, key) do
    serializer.encode_key(key, enc_key_opts)
  end
end
