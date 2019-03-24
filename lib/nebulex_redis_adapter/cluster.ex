defmodule NebulexRedisAdapter.Cluster do
  # Default Cluster
  @moduledoc false

  import NebulexRedisAdapter.Key

  alias Nebulex.Object
  alias NebulexRedisAdapter.Cluster.NodeSupervisor
  alias NebulexRedisAdapter.ConnectionPool

  ## API

  @spec children(Nebulex.Cache.t(), Keyword.t()) :: [Supervisor.child_spec()]
  def children(cache, opts) do
    for {node_name, node_opts} <- Keyword.get(opts, :nodes, []) do
      arg = {:"#{cache}_#{node_name}", node_opts}
      Supervisor.child_spec({NodeSupervisor, arg}, type: :supervisor, id: {cache, node_name})
    end
  end

  @spec get_conn(Nebulex.Cache.t(), hash_slot_or_key :: {:"$hash_slot", term} | term) :: atom
  def get_conn(cache, hash_slot_or_key)

  def get_conn(cache, {:"$hash_slot", node_name}) do
    pool_size = Keyword.fetch!(cache.__nodes__, node_name)
    ConnectionPool.get_conn(:"#{cache}_#{node_name}", pool_size)
  end

  def get_conn(cache, key) do
    {node, pool_size} = cache.get_node(key)
    ConnectionPool.get_conn(:"#{cache}_#{node}", pool_size)
  end

  def group_keys_by_hash_slot(enum, cache) do
    Enum.reduce(enum, %{}, fn
      %Object{key: key} = object, acc ->
        hash_slot = hash_slot(cache, key)
        Map.put(acc, hash_slot, [object | Map.get(acc, hash_slot, [])])

      key, acc ->
        hash_slot = hash_slot(cache, key)
        Map.put(acc, hash_slot, [key | Map.get(acc, hash_slot, [])])
    end)
  end

  @spec exec!(
          Nebulex.Cache.t(),
          Redix.command(),
          init_acc :: any,
          reducer :: (any, any -> any)
        ) :: any | no_return
  def exec!(cache, command, init_acc \\ nil, reducer \\ fn res, _ -> res end) do
    Enum.reduce(cache.__nodes__, init_acc, fn {node, pool_size}, acc ->
      :"#{cache}_#{node}"
      |> ConnectionPool.get_conn(pool_size)
      |> Redix.command!(command)
      |> reducer.(acc)
    end)
  end

  ## Private Functions

  defp hash_slot(cache, key) do
    node =
      key
      |> encode()
      |> cache.get_node()
      |> elem(0)

    {:"$hash_slot", node}
  end
end
