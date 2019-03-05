defmodule NebulexRedisAdapter.Cluster do
  # Redis Cluster Manager
  @moduledoc false

  alias NebulexRedisAdapter.Cluster.SlotSupervisor
  alias NebulexRedisAdapter.Command

  ## API

  @spec cluster_slots_tab(Nebulex.Cache.t()) :: atom
  def cluster_slots_tab(cache), do: :"#{cache}_cluster_slots"

  @spec children(Nebulex.Cache.t(), non_neg_integer, Keyword.t()) :: [Supervisor.child_spec()]
  def children(cache, pool_size, opts) do
    # get cluster config
    cluster_config = Keyword.fetch!(opts, :cluster)

    # create a connection and retrieve cluster slots map
    cluster_slots =
      cluster_config
      |> Keyword.fetch!(:master_nodes)
      |> get_cluster_slots()

    # init ETS table to store cluster slots
    _ = init_cluster_slots_table(cache)

    # create specs for children
    for [start, stop | nodes] <- cluster_slots do
      sup_name = :"#{cache}_#{start}_#{stop}"

      opts =
        opts
        |> Keyword.put(:name, sup_name)
        |> Keyword.put(:pool_size, pool_size)
        |> Keyword.put(:nodes, nodes)

      # store mapping between cluster slot and supervisor name
      true =
        cache
        |> cluster_slots_tab()
        |> :ets.insert({cache, start, stop, sup_name})

      # define child spec
      Supervisor.child_spec({SlotSupervisor, opts}, type: :supervisor, id: {Redix, {start, stop}})
    end
  end

  @spec exec!(
          Nebulex.Cache.t(),
          Redix.command(),
          reducer :: (any, any -> any),
          init_acc :: any
        ) :: any | no_return
  def exec!(cache, command, reducer \\ fn res, _ -> res end, init_acc \\ nil) do
    cache
    |> cluster_slots_tab()
    |> :ets.lookup(cache)
    |> Enum.reduce(init_acc, fn {_, _start, _stop, name}, acc ->
      cache
      |> Command.get_conn(name)
      |> Redix.command!(command)
      |> reducer.(acc)
    end)
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

  defp get_cluster_slots(master_nodes) do
    Enum.reduce_while(master_nodes, 1, fn conn_opts, acc ->
      with {:ok, conn} <- get_conn(conn_opts),
           {:ok, cluster_slots} <- Redix.command(conn, ["CLUSTER", "SLOTS"]) do
        {:halt, cluster_slots}
      else
        {:error, reason} ->
          if acc >= length(master_nodes) do
            raise reason
          else
            {:cont, acc + 1}
          end
      end
    end)
  end

  defp get_conn(conn_opts) do
    case conn_opts[:url] do
      nil ->
        Redix.start_link(conn_opts)

      url ->
        Redix.start_link(url, name: :redix_cluster)
    end
  end
end
