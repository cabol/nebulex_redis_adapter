defmodule NebulexRedisAdapter.RedisCluster do
  # Redis Cluster Manager
  @moduledoc false

  alias NebulexRedisAdapter.{Connection, Pool}
  alias NebulexRedisAdapter.RedisCluster.Keyslot, as: RedisClusterKeyslot

  @typedoc "Proxy type to the adapter meta"
  @type adapter_meta :: Nebulex.Adapter.metadata()

  # Redis cluster hash slots size
  @redis_cluster_hash_slots 16_384

  ## API

  @spec init(adapter_meta, Keyword.t()) :: {Supervisor.child_spec(), adapter_meta}
  def init(%{name: name, registry: registry, pool_size: pool_size} = adapter_meta, opts) do
    # Create a connection and retrieve hash slots map
    cluster_shards =
      opts
      |> get_master_nodes()
      |> get_cluster_shards()

    # Init ETS table to store hash slots
    cluster_shards_tab = init_cluster_shards_table(name)

    # Build specs for the cluster
    cluster_slot_specs =
      for {start, stop, master_host, master_port} <- cluster_shards do
        # Define slot id
        slot_id = {:cluster_shards, start, stop}

        # Store mapping between cluster slot and supervisor name
        true = :ets.insert(cluster_shards_tab, slot_id)

        # Define options
        opts =
          Keyword.merge(opts,
            slot_id: slot_id,
            registry: registry,
            pool_size: pool_size,
            master_host: master_host,
            master_port: master_port
          )

        # Define child spec
        Supervisor.child_spec(
          {NebulexRedisAdapter.RedisCluster.Supervisor, opts},
          type: :supervisor,
          id: slot_id
        )
      end

    cluster_shards_supervisor_spec = %{
      id: :cluster_shards_supervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [cluster_slot_specs, [strategy: :one_for_one]]}
    }

    adapter_meta =
      adapter_meta
      |> Map.put(:cluster_shards_tab, cluster_shards_tab)
      |> Map.update(:keyslot, RedisClusterKeyslot, &(&1 || RedisClusterKeyslot))

    {cluster_shards_supervisor_spec, adapter_meta}
  end

  @spec exec!(adapter_meta, Redix.command(), init_acc :: any, (any, any -> any)) :: any
  def exec!(
        %{registry: registry, pool_size: pool_size} = adapter_meta,
        command,
        init_acc \\ nil,
        reducer \\ fn res, _ -> res end
      ) do
    adapter_meta.cluster_shards_tab
    |> :ets.lookup(:cluster_shards)
    |> Enum.reduce(init_acc, fn slot_id, acc ->
      registry
      |> Pool.get_conn(slot_id, pool_size)
      |> Redix.command!(command)
      |> reducer.(acc)
    end)
  end

  @spec get_conn(adapter_meta, {:"$hash_slot", any} | any) :: pid | nil
  def get_conn(%{registry: registry, pool_size: pool_size} = adapter_meta, key) do
    {:"$hash_slot", hash_slot} =
      case key do
        {:"$hash_slot", _} -> key
        _ -> hash_slot(key, adapter_meta.keyslot)
      end

    adapter_meta.cluster_shards_tab
    |> :ets.lookup(:cluster_shards)
    |> Enum.reduce_while(nil, fn
      {_, start, stop} = slot_id, _acc when hash_slot >= start and hash_slot <= stop ->
        {:halt, Pool.get_conn(registry, slot_id, pool_size)}

      _, acc ->
        {:cont, acc}
    end)
  end

  @spec group_keys_by_hash_slot(Enum.t(), module) :: map
  def group_keys_by_hash_slot(enum, keyslot) do
    Enum.reduce(enum, %{}, fn
      {key, _} = entry, acc ->
        slot = hash_slot(key, keyslot)
        Map.put(acc, slot, [entry | Map.get(acc, slot, [])])

      key, acc ->
        slot = hash_slot(key, keyslot)
        Map.put(acc, slot, [key | Map.get(acc, slot, [])])
    end)
  end

  @spec hash_slot(any, module) :: {:"$hash_slot", pos_integer}
  def hash_slot(key, keyslot \\ RedisClusterKeyslot) do
    {:"$hash_slot", keyslot.hash_slot(key, @redis_cluster_hash_slots)}
  end

  ## Private Functions

  defp init_cluster_shards_table(name) do
    :ets.new(name, [
      :public,
      :duplicate_bag,
      read_concurrency: true
    ])
  end

  defp get_master_nodes(opts) do
    conn_opts = Connection.conn_opts(opts)

    for master_node_opts <- Keyword.get(opts, :master_nodes, [[]]) do
      Keyword.merge(conn_opts, master_node_opts)
    end
  end

  defp get_cluster_shards(master_nodes) do
    result =
      Enum.reduce_while(master_nodes, [], fn conn_opts, _acc ->
        with {:ok, conn} <- connect(conn_opts),
             {:ok, cluster_info} <- cluster_info(conn),
             command = cluster_command(cluster_info["redis_version"]),
             {:ok, cluster_info} <- Redix.command(conn, command) do
          {:halt, parse_cluster_info(cluster_info)}
        else
          {:error, _} = error -> {:cont, error}
        end
      end)

    with {:error, reason} <- result do
      exit(reason)
    end
  end

  defp connect(conn_opts) do
    case Keyword.pop(conn_opts, :url) do
      {nil, conn_opts} ->
        Redix.start_link(conn_opts)

      {url, conn_opts} ->
        Redix.start_link(url, [name: :redix_cluster] ++ conn_opts)
    end
  end

  defp cluster_info(conn) do
    with {:ok, raw_info} <- Redix.command(conn, ["INFO", "server"]) do
      cluster_info =
        raw_info
        |> String.split(["\r\n", "\n"], trim: true)
        |> Enum.reduce(%{}, fn str, acc ->
          case String.split(str, ":", trim: true) do
            [key, value] -> Map.put(acc, key, value)
            _other -> acc
          end
        end)

      {:ok, cluster_info}
    end
  end

  defp cluster_command(<<major::bytes-size(1), _rest::bytes>>) do
    case Integer.parse(major) do
      {v, _} when v >= 7 ->
        ["CLUSTER", "SHARDS"]

      _else ->
        ["CLUSTER", "SLOTS"]
    end
  end

  # coveralls-ignore-start

  defp cluster_command(_) do
    ["CLUSTER", "SLOTS"]
  end

  # coveralls-ignore-stop

  defp parse_cluster_info(config) do
    Enum.reduce(config, [], fn
      # Redis 7 or higher (["CLUSTER", "SHARDS"])
      ["slots", [start, stop], "nodes", nodes], acc ->
        {host, port} =
          for [
                "id",
                _,
                "port",
                port,
                "ip",
                ip,
                "endpoint",
                endpoint,
                "role",
                "master",
                "replication-offset",
                _,
                "health",
                "online"
              ] <- nodes do
            {endpoint || ip, port}
          end
          |> hd()

        [{start, stop, host, port} | acc]

      # Redis 6 or lower (["CLUSTER", "SLOTS"])
      [start, stop, [host, port | _tail] = _master | _replicas], acc ->
        [{start, stop, host, port} | acc]
    end)
  end
end
