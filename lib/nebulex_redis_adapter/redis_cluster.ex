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
    # Create a connection and retrieve cluster slots map
    cluster_slots =
      opts
      |> get_master_nodes()
      |> get_cluster_slots()

    # Init ETS table to store cluster slots
    cluster_slots_tab = init_cluster_slots_table(name)

    # Build specs for the cluster slots
    cluster_slot_specs =
      for [start, stop | nodes] <- cluster_slots do
        # Define slot id
        slot_id = {:cluster_slots, start, stop}

        # Store mapping between cluster slot and supervisor name
        true = :ets.insert(cluster_slots_tab, slot_id)

        # Define options
        opts =
          Keyword.merge(opts,
            slot_id: slot_id,
            registry: registry,
            pool_size: pool_size,
            nodes: nodes
          )

        # Define child spec
        Supervisor.child_spec(
          {NebulexRedisAdapter.RedisCluster.Supervisor, opts},
          type: :supervisor,
          id: slot_id
        )
      end

    cluster_slots_supervisor_spec = %{
      id: :cluster_slots_supervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [cluster_slot_specs, [strategy: :one_for_one]]}
    }

    adapter_meta =
      adapter_meta
      |> Map.put(:cluster_slots_tab, cluster_slots_tab)
      |> Map.update(:keyslot, RedisClusterKeyslot, &(&1 || RedisClusterKeyslot))

    {cluster_slots_supervisor_spec, adapter_meta}
  end

  @spec exec!(adapter_meta, Redix.command(), init_acc :: any, (any, any -> any)) :: any
  def exec!(
        %{registry: registry, pool_size: pool_size} = adapter_meta,
        command,
        init_acc \\ nil,
        reducer \\ fn res, _ -> res end
      ) do
    adapter_meta.cluster_slots_tab
    |> :ets.lookup(:cluster_slots)
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

    adapter_meta.cluster_slots_tab
    |> :ets.lookup(:cluster_slots)
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

  defp init_cluster_slots_table(name) do
    :ets.new(name, [
      :public,
      :duplicate_bag,
      read_concurrency: true
    ])
  end

  defp get_master_nodes(opts) do
    Keyword.get(opts, :master_nodes, [Connection.conn_opts(opts)])
  end

  defp get_cluster_slots(master_nodes) do
    Enum.reduce_while(master_nodes, 1, fn conn_opts, acc ->
      with {:ok, conn} <- connect(conn_opts),
           {:ok, cluster_slots} <- Redix.command(conn, ["CLUSTER", "SLOTS"]) do
        {:halt, cluster_slots}
      else
        {:error, reason} ->
          if acc >= length(master_nodes) do
            exit(reason)
          else
            {:cont, acc + 1}
          end
      end
    end)
  end

  defp connect(conn_opts) do
    if url = Keyword.get(conn_opts, :url) do
      Redix.start_link(url, name: :redix_cluster)
    else
      Redix.start_link(conn_opts)
    end
  end
end
