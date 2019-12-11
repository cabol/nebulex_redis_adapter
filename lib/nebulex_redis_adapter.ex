defmodule NebulexRedisAdapter do
  @moduledoc """
  Nebulex adapter for Redis.

  This adapter is implemented using `Redix`, a Redis driver for
  Elixir.

  **NebulexRedisAdapter** brings with three setup alternatives: standalone
  (default) and two more for cluster support:

    * **Standalone** - This is the default mode, the adapter establishes a pool
      of connections against a single Redis node.

    * **Redis Cluster** - Redis can be setup in distributed fashion by means of
      **Redis Cluster**, which is a built-in feature since version 3.0
      (or greater). This adapter provides the `:redis_cluster` mode to setup
      **Redis Cluster** from client-side automatically and be able to use it
      transparently.

    * **Built-in client-side cluster based on sharding** - This adapter provides
      a simple client-side cluster implementation based on Sharding as
      distribution model and consistent hashing for node resolution.

  ## Shared Options

  In addition to `Nebulex.Cache` shared options, this adapters supports the
  following options:

    * `:mode` - Defines the mode Redis will be set up. It can be one of the
      next values: `:standalone | :cluster | :redis_cluster`. Defaults to
      `:standalone`.

    * `:pool_size` - Number of connections to keep in the pool.
      Defaults to `System.schedulers_online()`.

    * `:conn_opts` - Redis client options (`Redix` options in this case).
      For more information about the options (Redis and connection options),
      please check out `Redix` docs.

    * `:default_data_type` - Sets the default data type for encoding Redis
      values. Defaults to `:object`. For more information, check the
      "Data Types" section below.

    * `:dt` - This option is only valid for set-like operations and allows us
      to change the Redis value encoding via this option. This option overrides
      `:default_data_type`. Defaults to `:object`. For more information, check
      the "Data Types" section below.

  ## Data Types

  This adapter supports different ways to encode and store Redis values,
  regarding the data type we are working with. Supported values:

    * `:object` - By default, the value stored in Redis is the
      `Nebulex.Object.t()` itself, before to insert it, it is encoded as binary
      using `:erlang.term_to_binary/1`. The downside is it consumes more memory
      since the object contains not only the value but also the key, the TTL,
      and the version. This is the default.

    * `:string` - If this option is set and the object value can be converted
      to a valid string (e.g.: strings, integers, atoms), then that string is
      stored directly in Redis without any encoding.

  ### Usage Example

      MyCache.set("foo", "bar", dt: :string)

      MyCache.set("int", 123, dt: :string)

      MyCache.set("atom", :atom, dt: :string)

  **NOTE:** Support for other Redis Data Types is in progress.

  ## Standalone Example

  We can define our cache to use Redis adapter as follows:

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

  ## Redis Cluster Options

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

  ## Redis Cluster Example

      config :my_app, MayApp.RedisClusterCache,
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

  ## Client-side Cluster Options

  In addition to shared options, `:cluster` mode supports the following
  options:

    * `:nodes` - The list of nodes the adapter will setup the cluster with;
      a pool of connections is established per node. The `:cluster` mode
      enables resilience, be able to survive in case any node(s) gets
      unreachable. For each element of the list, we set the configuration
      for each node, such as `:conn_opts`, `:pool_size`, etc.

  ## Clustered Cache Example

      config :my_app, MayApp.ClusteredCache,
        mode: :cluster,
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

  ## Queryable API

  The queryable API is implemented by means of `KEYS` command, but it has some
  limitations we have to be aware of:

    * Only strings (`String.t()`) are allowed as query parameter.

    * Only keys can be queried. Therefore, `:return` option has not any affects,
      since keys are always returned. In the case you want to return the value
      for the given key pattern (query), you can perform `get_many` with the
      returned keys.

  ## Examples

      iex> MyApp.RedisCache.set_many(%{
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
      iex> "**name**" |> MyApp.RedisCache.all() |> MyApp.RedisCache.get_many()
      %{"firstname" => "Albert", "lastname" => "Einstein"}

  For more information about the usage, check out `Nebulex.Cache` as well.
  """

  # Inherit default transaction implementation
  use Nebulex.Adapter.Transaction

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Queryable

  import NebulexRedisAdapter.Encoder

  alias Nebulex.Object
  alias NebulexRedisAdapter.{Cluster, Command, Connection, RedisCluster}

  @default_pool_size System.schedulers_online()

  ## Adapter

  @impl true
  defmacro __before_compile__(env) do
    config = Module.get_attribute(env.module, :config)
    mode = Keyword.get(config, :mode, :standalone)
    pool_size = Keyword.get(config, :pool_size, @default_pool_size)
    hash_slot = Keyword.get(config, :hash_slot)
    default_dt = Keyword.get(config, :default_data_type, :object)

    nodes =
      for {node_name, node_opts} <- Keyword.get(config, :nodes, []) do
        {node_name, Keyword.get(node_opts, :pool_size, @default_pool_size)}
      end

    quote do
      def __mode__, do: unquote(mode)

      def __pool_size__, do: unquote(pool_size)

      def __nodes__, do: unquote(nodes)

      cond do
        unquote(hash_slot) ->
          def __hash_slot__, do: unquote(hash_slot)

        unquote(mode) == :redis_cluster ->
          def __hash_slot__, do: RedisCluster

        true ->
          def __hash_slot__, do: Cluster
      end

      def get_data_type(opts) do
        Keyword.get(opts, :dt, unquote(default_dt))
      end
    end
  end

  @impl true
  def init(opts) do
    cache = Keyword.fetch!(opts, :cache)

    case cache.__mode__ do
      :standalone ->
        Connection.init(opts)

      :cluster ->
        NebulexCluster.init([connection_module: NebulexRedisAdapter.Connection] ++ opts)

      :redis_cluster ->
        RedisCluster.init(opts)
    end
  end

  @impl true
  def get(cache, key, opts) do
    opts
    |> Keyword.get(:return)
    |> with_ttl(cache, key, [["GET", encode(key)]])
  end

  @impl true
  def get_many(cache, keys, _opts) do
    do_get_many(cache.__mode__, cache, keys)
  end

  defp do_get_many(:standalone, cache, keys) do
    mget(nil, cache, keys)
  end

  defp do_get_many(mode, cache, keys) do
    keys
    |> group_keys_by_hash_slot(cache, mode)
    |> Enum.reduce(%{}, fn {hash_slot, keys}, acc ->
      return = mget(hash_slot, cache, keys)
      Map.merge(acc, return)
    end)
  end

  defp mget(hash_slot_key, cache, keys) do
    cache
    |> Command.exec!(["MGET" | for(k <- keys, do: encode(k))], hash_slot_key)
    |> Enum.reduce({keys, %{}}, fn
      nil, {[_key | keys], acc} ->
        {keys, acc}

      entry, {[key | keys], acc} ->
        value =
          entry
          |> decode()
          |> object(key, -1)

        {keys, Map.put(acc, key, value)}
    end)
    |> elem(1)
  end

  @impl true
  def set(cache, object, opts) do
    cmd_opts = cmd_opts(opts, action: :set, ttl: nil)
    redis_k = encode(object.key)
    redis_v = encode(object, cache.get_data_type(opts))

    case Command.exec!(cache, ["SET", redis_k, redis_v | cmd_opts], redis_k) do
      "OK" -> true
      nil -> false
    end
  end

  @impl true
  def set_many(cache, objects, opts) do
    set_many(cache.__mode__, cache, objects, opts)
  end

  defp set_many(:standalone, cache, objects, opts) do
    do_set_many(nil, cache, objects, opts)
  end

  defp set_many(mode, cache, objects, opts) do
    objects
    |> group_keys_by_hash_slot(cache, mode)
    |> Enum.each(fn {hash_slot, objects} ->
      do_set_many(hash_slot, cache, objects, opts)
    end)
  end

  defp do_set_many(hash_slot_or_key, cache, objects, opts) do
    dt = cache.get_data_type(opts)

    default_exp =
      opts
      |> Keyword.get(:ttl)
      |> Object.expire_at()

    {mset, expire} =
      Enum.reduce(objects, {["MSET"], []}, fn object, {acc1, acc2} ->
        redis_k = encode(object.key)

        acc2 =
          if expire_at = object.expire_at || default_exp,
            do: [["EXPIRE", redis_k, Object.remaining_ttl(expire_at)] | acc2],
            else: acc2

        {[encode(object, dt), redis_k | acc1], acc2}
      end)

    ["OK" | _] = Command.pipeline!(cache, [Enum.reverse(mset) | expire], hash_slot_or_key)
    :ok
  end

  defp group_keys_by_hash_slot(enum, cache, :cluster) do
    Cluster.group_keys_by_hash_slot(enum, cache)
  end

  defp group_keys_by_hash_slot(enum, cache, :redis_cluster) do
    RedisCluster.group_keys_by_hash_slot(enum, cache)
  end

  @impl true
  def delete(cache, key, _opts) do
    redis_k = encode(key)
    _ = Command.exec!(cache, ["DEL", redis_k], redis_k)
    :ok
  end

  @impl true
  def take(cache, key, opts) do
    redis_k = encode(key)

    opts
    |> Keyword.get(:return)
    |> with_ttl(cache, key, [["GET", redis_k], ["DEL", redis_k]])
  end

  @impl true
  def has_key?(cache, key) do
    redis_k = encode(key)

    case Command.exec!(cache, ["EXISTS", redis_k], redis_k) do
      1 -> true
      0 -> false
    end
  end

  @impl true
  def object_info(cache, key, :ttl) do
    redis_k = encode(key)

    case Command.exec!(cache, ["TTL", redis_k], redis_k) do
      -1 -> :infinity
      -2 -> nil
      ttl -> ttl
    end
  end

  def object_info(cache, key, :version) do
    case get(cache, key, []) do
      nil -> nil
      obj -> obj.version
    end
  end

  @impl true
  def expire(cache, key, :infinity) do
    redis_k = encode(key)

    case Command.pipeline!(cache, [["TTL", redis_k], ["PERSIST", redis_k]], redis_k) do
      [-2, 0] -> nil
      [_, _] -> :infinity
    end
  end

  def expire(cache, key, ttl) do
    redis_k = encode(key)

    case Command.exec!(cache, ["EXPIRE", redis_k, ttl], redis_k) do
      1 -> Object.expire_at(ttl) || :infinity
      0 -> nil
    end
  end

  @impl true
  def update_counter(cache, key, incr, _opts) when is_integer(incr) do
    redis_k = encode(key)
    Command.exec!(cache, ["INCRBY", redis_k, incr], redis_k)
  end

  @impl true
  def size(cache) do
    exec!(cache.__mode__, [cache, ["DBSIZE"]], [0, &Kernel.+(&2, &1)])
  end

  @impl true
  def flush(cache) do
    _ = exec!(cache.__mode__, [cache, ["FLUSHDB"]], [])
    :ok
  end

  ## Queryable

  @impl true
  def all(cache, query, _opts) do
    query
    |> validate_query()
    |> execute_query(cache)
  end

  @impl true
  def stream(cache, query, _opts) do
    query
    |> validate_query()
    |> do_stream(cache)
  end

  defp do_stream(pattern, cache) do
    Stream.resource(
      fn ->
        execute_query(pattern, cache)
      end,
      fn
        [] -> {:halt, []}
        elems -> {elems, []}
      end,
      & &1
    )
  end

  ## Private Functions

  defp with_ttl(:object, cache, key, pipeline) do
    redis_k = encode(key)

    case Command.pipeline!(cache, [["TTL", redis_k] | pipeline], redis_k) do
      [-2 | _] ->
        nil

      [ttl, get | _] ->
        get
        |> decode()
        |> object(key, ttl)
    end
  end

  defp with_ttl(_, cache, key, pipeline) do
    redis_k = encode(key)

    cache
    |> Command.pipeline!(pipeline, redis_k)
    |> hd()
    |> decode()
    |> object(key, -1)
  end

  defp object(nil, _key, _ttl), do: nil
  defp object(%Object{} = obj, _key, -1), do: obj

  defp object(%Object{} = obj, _key, ttl) do
    %{obj | expire_at: Object.expire_at(ttl)}
  end

  defp object(value, key, _ttl) when is_binary(value) do
    %Object{key: key, value: value}
  end

  defp cmd_opts(opts, keys) do
    Enum.reduce(keys, [], fn {key, default}, acc ->
      opts
      |> Keyword.get(key, default)
      |> cmd_opts(key, acc)
    end)
  end

  defp cmd_opts(nil, _opt, acc), do: acc
  defp cmd_opts(:set, :action, acc), do: acc
  defp cmd_opts(:add, :action, acc), do: ["NX" | acc]
  defp cmd_opts(:replace, :action, acc), do: ["XX" | acc]
  defp cmd_opts(ttl, :ttl, acc), do: ["EX", ttl | acc]

  defp validate_query(nil), do: "*"
  defp validate_query(pattern) when is_binary(pattern), do: pattern

  defp validate_query(pattern) do
    raise Nebulex.QueryError, message: "invalid pattern", query: pattern
  end

  defp execute_query(pattern, cache) do
    exec!(cache.__mode__, [cache, ["KEYS", pattern]], [[], &Kernel.++(&1, &2)])
  end

  defp exec!(:standalone, args, _extra_args) do
    apply(Command, :exec!, args)
  end

  defp exec!(:cluster, args, extra_args) do
    apply(Cluster, :exec!, args ++ extra_args)
  end

  defp exec!(:redis_cluster, args, extra_args) do
    apply(RedisCluster, :exec!, args ++ extra_args)
  end
end
