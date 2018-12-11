defmodule NebulexRedisAdapter do
  @moduledoc """
  Nebulex adapter for Redis.

  This adapter is implemented by means of `Redix`, a Redis driver for
  Elixir.

  This adapter supports multiple connection pools against different Redis
  nodes in a cluster. This feature enables resiliency, be able to survive
  in case any node(s) gets unreachable.

  ## Adapter Options

  In addition to `Nebulex.Cache` shared options, this adapters supports the
  following options:

    * `:pools` - The list of connection pools for Redis. Each element (pool)
      holds the same options as `Redix` (including connection options), and
      the `:pool_size` (number of connections to keep in the pool).

  ## Redix Options (for each pool)

  Since this adapter is implemented by means of `Redix`, it inherits the same
  options (including connection options). These are some of the main ones:

    * `:host` - (string) the host where the Redis server is running. Defaults to
      `"localhost"`.

    * `:port` - (positive integer) the port on which the Redis server is
      running. Defaults to `6379`.

    * `:password` - (string) the password used to connect to Redis. Defaults to
      `nil`, meaning no password is used. When this option is provided, all
       Redix does is issue an `AUTH` command to Redis in order to authenticate.

    * `:database` - (non-negative integer or string) the database to connect to.
      Defaults to `nil`, meaning Redix doesn't connect to a specific database
      (the default in this case is database `0`). When this option is provided,
      all Redix does is issue a `SELECT` command to Redis in order to select the
      given database.

  For more information about the options (Redis and connection options), please
  checkout `Redix` docs.

  In addition to `Redix` options, it supports:

    * `:pool_size` - The number of connections to keep in the pool
      (default: `System.schedulers_online()`).

  ## Example

  We can define our cache to use Redis adapter as follows:

      defmodule MyApp.RedisCache do
        use Nebulex.Cache,
          otp_app: :nebulex,
          adapter: NebulexRedisAdapter
      end

  The configuration for the cache must be in your application environment,
  usually defined in your `config/config.exs`:

      config :my_app, MyApp.RedisCache,
        pools: [
          primary: [
            host: "127.0.0.1",
            port: 6379
          ],
          secondary: [
            url: "redis://10.10.10.10:6379",
            pool_size: 2
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

  alias Nebulex.Object
  alias NebulexRedisAdapter.Command

  @default_pool_size System.schedulers_online()

  ## Adapter

  @impl true
  defmacro __before_compile__(env) do
    otp_app = Module.get_attribute(env.module, :otp_app)
    config = Module.get_attribute(env.module, :config)

    pool_size =
      if pools = Keyword.get(config, :pools) do
        Enum.reduce(pools, 0, fn {_, pool}, acc ->
          acc + Keyword.get(pool, :pool_size, @default_pool_size)
        end)
      else
        raise ArgumentError,
              "missing :pools configuration in " <>
                "config #{inspect(otp_app)}, #{inspect(env.module)}"
      end

    quote do
      def __pool_size__, do: unquote(pool_size)
    end
  end

  @impl true
  def init(opts) do
    cache = Keyword.fetch!(opts, :cache)

    children =
      opts
      |> Keyword.fetch!(:pools)
      |> Enum.reduce([], fn {_, pool}, acc ->
        acc ++ children(pool, cache, acc)
      end)

    {:ok, children}
  end

  defp children(pool, cache, acc) do
    offset = length(acc)
    pool_size = Keyword.get(pool, :pool_size, @default_pool_size)

    for i <- offset..(offset + pool_size - 1) do
      opts =
        pool
        |> Keyword.delete(:pool_size)
        |> Keyword.put(:name, :"#{cache}_redix_#{i}")

      case opts[:url] do
        nil ->
          Supervisor.child_spec({Redix, opts}, id: {Redix, i})

        url ->
          opts = opts |> Keyword.delete(:url)
          Supervisor.child_spec({Redix, {url, opts}}, id: {Redix, i})
      end
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
    cache
    |> Command.exec!(["MGET" | for(k <- keys, do: encode(k))])
    |> Enum.reduce({keys, %{}}, fn
      nil, {[_key | keys], acc} ->
        {keys, acc}

      entry, {[key | keys], acc} ->
        {keys, Map.put(acc, key, decode(entry))}
    end)
    |> elem(1)
  end

  @impl true
  def set(cache, object, opts) do
    cmd_opts = cmd_opts(opts, action: :set, ttl: nil)

    case Command.exec!(cache, ["SET", encode(object.key), encode(object) | cmd_opts]) do
      "OK" -> true
      nil -> false
    end
  end

  @impl true
  def set_many(cache, objects, opts) do
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

        {[encode(object), redis_k | acc1], acc2}
      end)

    ["OK" | _] = Command.pipeline!(cache, [Enum.reverse(mset) | expire])
    :ok
  end

  @impl true
  def delete(cache, key, _opts) do
    _ = Command.exec!(cache, ["DEL", encode(key)])
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
    case Command.exec!(cache, ["EXISTS", encode(key)]) do
      1 -> true
      0 -> false
    end
  end

  @impl true
  def object_info(cache, key, :ttl) do
    case Command.exec!(cache, ["TTL", encode(key)]) do
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
    key = encode(key)

    case Command.pipeline!(cache, [["TTL", key], ["PERSIST", key]]) do
      [-2, 0] -> nil
      [_, _] -> :infinity
    end
  end

  def expire(cache, key, ttl) do
    case Command.exec!(cache, ["EXPIRE", encode(key), ttl]) do
      1 -> Object.expire_at(ttl) || :infinity
      0 -> nil
    end
  end

  @impl true
  def update_counter(cache, key, incr, _opts) when is_integer(incr) do
    Command.exec!(cache, ["INCRBY", encode(key), incr])
  end

  @impl true
  def size(cache) do
    Command.exec!(cache, ["DBSIZE"])
  end

  @impl true
  def flush(cache) do
    _ = Command.exec!(cache, ["FLUSHALL"])
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
    case Command.pipeline!(cache, [["TTL", encode(key)] | pipeline]) do
      [-2 | _] ->
        nil

      [ttl, get | _] ->
        get
        |> decode()
        |> object(key, ttl)
    end
  end

  defp with_ttl(_, cache, key, pipeline) do
    cache
    |> Command.pipeline!(pipeline)
    |> hd()
    |> decode()
    |> object(key, -1)
  end

  defp encode(data) do
    to_string(data)
  rescue
    _e -> :erlang.term_to_binary(data)
  end

  defp decode(nil), do: nil

  defp decode(data) do
    if String.printable?(data) do
      data
    else
      :erlang.binary_to_term(data)
    end
  end

  defp object(nil, _key, _ttl), do: nil
  defp object(%Object{} = obj, _key, -1), do: obj

  defp object(%Object{} = obj, _key, ttl) do
    %{obj | expire_at: Object.expire_at(ttl)}
  end

  defp object(value, key, -1) do
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
    Command.exec!(cache, ["KEYS", pattern])
  end
end
