defmodule NebulexRedisAdapter.RedisCluster do
  # Redis Cluster Manager
  @moduledoc false

  alias NebulexCluster.Pool
  alias NebulexRedisAdapter.Connection
  alias NebulexRedisAdapter.RedisCluster.NodeSupervisor

  @compile {:inline, cluster_slots_tab: 1}

  @redis_cluster_hash_slots 16_384

  ## API

  @spec init(atom, pos_integer, Keyword.t()) :: {:ok, [Supervisor.child_spec()]}
  def init(name, pool_size, opts) do
    # create a connection and retrieve cluster slots map
    cluster_slots =
      opts
      |> get_master_nodes()
      |> get_cluster_slots()

    # init ETS table to store cluster slots
    _ = init_cluster_slots_table(name)

    # create specs for children
    children =
      for [start, stop | nodes] <- cluster_slots do
        sup_name = :"#{name}.#{start}.#{stop}"

        opts =
          opts
          |> Keyword.put(:name, sup_name)
          |> Keyword.put(:pool_size, pool_size)
          |> Keyword.put(:nodes, nodes)

        # store mapping between cluster slot and supervisor name
        true =
          name
          |> cluster_slots_tab()
          |> :ets.insert({name, start, stop, sup_name})

        # define child spec
        Supervisor.child_spec({NodeSupervisor, opts},
          type: :supervisor,
          id: {Redix, {start, stop}}
        )
      end

    {:ok, children}
  end

  @spec get_conn(Nebulex.Adapter.adapter_meta(), {:"$hash_slot", any} | any) :: atom
  def get_conn(%{name: name, pool_size: pool_size}, {:"$hash_slot", _} = key) do
    get_conn(name, pool_size, key)
  end

  def get_conn(%{name: name, pool_size: pool_size, keyslot: keyslot}, key) do
    get_conn(name, pool_size, hash_slot(key, keyslot))
  end

  defp get_conn(name, pool_size, {:"$hash_slot", hash_slot}) do
    name
    |> cluster_slots_tab()
    |> :ets.lookup(name)
    |> Enum.reduce_while(nil, fn
      {_, start, stop, name}, _acc when hash_slot >= start and hash_slot <= stop ->
        {:halt, Pool.get_conn(name, pool_size)}

      _, acc ->
        {:cont, acc}
    end)
  end

  @spec exec!(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          init_acc :: any,
          reducer :: (any, any -> any)
        ) :: any | no_return
  def exec!(
        %{name: name, pool_size: pool_size},
        command,
        init_acc \\ nil,
        reducer \\ fn res, _ -> res end
      ) do
    # TODO: Perhaps this should be performed in parallel
    name
    |> cluster_slots_tab()
    |> :ets.lookup(name)
    |> Enum.reduce(init_acc, fn {_, _start, _stop, name}, acc ->
      name
      |> Pool.get_conn(pool_size)
      |> Redix.command!(command)
      |> reducer.(acc)
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
  def hash_slot(key, keyslot \\ __MODULE__.Keyslot) do
    {:"$hash_slot", keyslot.hash_slot(key, @redis_cluster_hash_slots)}
  end

  @spec cluster_slots_tab(atom) :: atom
  def cluster_slots_tab(name), do: :"#{name}.ClusterSlots"

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

defmodule NebulexRedisAdapter.RedisCluster.Keyslot do
  @moduledoc false
  use Nebulex.Adapter.Keyslot

  import NebulexRedisAdapter.Encoder

  @impl true
  def hash_slot("{" <> hash_tags = key, range) do
    case String.split(hash_tags, "}") do
      [key, _] -> do_hash_slot(key, range)
      _ -> do_hash_slot(key, range)
    end
  end

  def hash_slot(key, range) when is_binary(key) do
    do_hash_slot(key, range)
  end

  def hash_slot(key, range) do
    key
    |> encode()
    |> do_hash_slot(range)
  end

  defp do_hash_slot(key, range) do
    :crc_16_xmodem
    |> CRC.crc(key)
    |> rem(range)
  end
end
