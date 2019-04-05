defmodule NebulexRedisAdapter.Cluster do
  # Default Cluster
  @moduledoc false

  use Nebulex.Adapter.HashSlot

  import NebulexRedisAdapter.String

  alias NebulexCluster.Pool

  ## API

  @spec exec!(
          Nebulex.Cache.t(),
          Redix.command(),
          init_acc :: any,
          reducer :: (any, any -> any)
        ) :: any | no_return
  def exec!(cache, command, init_acc \\ nil, reducer \\ fn res, _ -> res end) do
    Enum.reduce(cache.__nodes__, init_acc, fn {node_name, pool_size}, acc ->
      cache
      |> NebulexCluster.pool_name(node_name)
      |> Pool.get_conn(pool_size)
      |> Redix.command!(command)
      |> reducer.(acc)
    end)
  end

  @spec group_keys_by_hash_slot(Enum.t(), Nebulex.Cache.t()) :: map
  def group_keys_by_hash_slot(enum, cache) do
    NebulexCluster.group_keys_by_hash_slot(enum, cache.__nodes__, cache.__hash_slot__)
  end

  ## Nebulex.Adapter.HashSlot

  @impl true
  def keyslot(key, range) when is_binary(key) do
    key
    |> :erlang.phash2()
    |> :jchash.compute(range)
  end

  def keyslot(key, range) do
    key
    |> encode()
    |> keyslot(range)
  end
end
