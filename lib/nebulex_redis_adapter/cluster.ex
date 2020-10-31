defmodule NebulexRedisAdapter.Cluster do
  # Default Cluster
  @moduledoc false

  alias NebulexCluster.Pool

  ## API

  @spec exec!(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          init_acc :: any,
          reducer :: (any, any -> any)
        ) :: any | no_return
  def exec!(
        %{name: name, nodes: nodes},
        command,
        init_acc \\ nil,
        reducer \\ fn res, _ -> res end
      ) do
    # TODO: Perhaps this should be performed in parallel
    Enum.reduce(nodes, init_acc, fn {node_name, pool_size}, acc ->
      name
      |> NebulexCluster.pool_name(node_name)
      |> Pool.get_conn(pool_size)
      |> Redix.command!(command)
      |> reducer.(acc)
    end)
  end

  @spec group_keys_by_hash_slot(Enum.t(), [node], module) :: map
  defdelegate group_keys_by_hash_slot(enum, nodes, keyslot), to: NebulexCluster
end
