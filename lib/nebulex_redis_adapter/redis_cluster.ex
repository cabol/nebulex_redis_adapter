defmodule NebulexRedisAdapter.RedisCluster do
  # Redis Cluster Manager
  @moduledoc false

  use Nebulex.Adapter.HashSlot

  import NebulexRedisAdapter.String

  alias NebulexCluster.Pool
  alias NebulexRedisAdapter.Connection
  alias NebulexRedisAdapter.RedisCluster.NodeSupervisor

  @redis_cluster_hash_slots 16_384

  ## API

  @spec init(Keyword.t()) :: {:ok, [Supervisor.child_spec()]}
  def init(opts) do
    # get cache
    cache = Keyword.fetch!(opts, :cache)

    # create a connection and retrieve cluster slots map
    cluster_slots =
      opts
      |> get_master_nodes()
      |> get_cluster_slots()

    # init ETS table to store cluster slots
    _ = init_cluster_slots_table(cache)

    # create specs for children
    children =
      for [start, stop | nodes] <- cluster_slots do
        sup_name = :"#{cache}.#{start}.#{stop}"

        opts =
          opts
          |> Keyword.put(:name, sup_name)
          |> Keyword.put(:pool_size, cache.__pool_size__)
          |> Keyword.put(:nodes, nodes)

        # store mapping between cluster slot and supervisor name
        true =
          cache
          |> cluster_slots_tab()
          |> :ets.insert({cache, start, stop, sup_name})

        # define child spec
        Supervisor.child_spec({NodeSupervisor, opts},
          type: :supervisor,
          id: {Redix, {start, stop}}
        )
      end

    {:ok, children}
  end

  @spec get_conn(Nebulex.Cache.t(), any) :: atom
  def get_conn(cache, {:"$hash_slot", hash_slot}) do
    cache
    |> cluster_slots_tab()
    |> :ets.lookup(cache)
    |> Enum.reduce_while(nil, fn
      {_, start, stop, name}, _acc when hash_slot >= start and hash_slot <= stop ->
        {:halt, Pool.get_conn(name, cache.__pool_size__)}

      _, acc ->
        {:cont, acc}
    end)
  end

  def get_conn(cache, key) do
    get_conn(cache, hash_slot(cache, key))
  end

  @spec exec!(
          Nebulex.Cache.t(),
          Redix.command(),
          init_acc :: any,
          reducer :: (any, any -> any)
        ) :: any | no_return
  def exec!(cache, command, init_acc \\ nil, reducer \\ fn res, _ -> res end) do
    cache
    |> cluster_slots_tab()
    |> :ets.lookup(cache)
    |> Enum.reduce(init_acc, fn {_, _start, _stop, name}, acc ->
      name
      |> Pool.get_conn(cache.__pool_size__)
      |> Redix.command!(command)
      |> reducer.(acc)
    end)
  end

  @spec group_keys_by_hash_slot(Enum.t(), Nebulex.Cache.t()) :: map
  def group_keys_by_hash_slot(enum, cache) do
    Enum.reduce(enum, %{}, fn
      %Nebulex.Object{key: key} = object, acc ->
        slot = hash_slot(cache, key)
        Map.put(acc, slot, [object | Map.get(acc, slot, [])])

      key, acc ->
        slot = hash_slot(cache, key)
        Map.put(acc, slot, [key | Map.get(acc, slot, [])])
    end)
  end

  @spec hash_slot(Nebulex.Cache.t(), any) :: {:"$hash_slot", pos_integer}
  def hash_slot(cache, key) do
    {:"$hash_slot", cache.__hash_slot__.keyslot(key, @redis_cluster_hash_slots)}
  end

  @spec cluster_slots_tab(Nebulex.Cache.t()) :: atom
  def cluster_slots_tab(cache), do: :"#{cache}.ClusterSlots"

  ## Nebulex.Adapter.HashSlot

  @impl true
  def keyslot("{" <> hash_tags = key, range) do
    case String.split(hash_tags, "}") do
      [key, _] -> do_keyslot(key, range)
      _ -> do_keyslot(key, range)
    end
  end

  def keyslot(key, range) when is_binary(key) do
    do_keyslot(key, range)
  end

  def keyslot(key, range) do
    key
    |> encode()
    |> do_keyslot(range)
  end

  defp do_keyslot(key, range) do
    :crc_16_xmodem
    |> CRC.crc(encode(key))
    |> rem(range)
  end

  ## Private Functions

  defp init_cluster_slots_table(cache) do
    cache
    |> cluster_slots_tab()
    |> :ets.new([
      :named_table,
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
    case conn_opts[:url] do
      nil -> Redix.start_link(conn_opts)
      url -> Redix.start_link(url, name: :redix_cluster)
    end
  end
end
