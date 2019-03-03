defmodule NebulexRedisAdapter.Command do
  # Redix command executor
  @moduledoc false

  alias NebulexRedisAdapter.Cluster

  @spec exec!(Nebulex.Cache.t(), Redix.command(), Nebulex.Cache.key()) :: any | no_return
  def exec!(cache, command, key \\ nil) do
    cache
    |> get_conn(key)
    |> Redix.command!(command)
  end

  @spec pipeline!(Nebulex.Cache.t(), [Redix.command()], Nebulex.Cache.key()) :: [any] | no_return
  def pipeline!(cache, command, key \\ nil) do
    cache
    |> get_conn(key)
    |> Redix.pipeline!(command)
  end

  ## Private Functions

  defp get_conn(cache, key) do
    get_conn(cache, key, cache.cluster_enabled?)
  end

  defp get_conn(cache, _key, false) do
    index = rem(System.unique_integer([:positive]), cache.__pool_size__)
    :"#{cache}_redix_#{index}"
  end

  defp get_conn(cache, key, true) do
    key
    |> cache.keyslot()
    |> get_cluster_slot_conn(cache)
  end

  defp get_cluster_slot_conn(hash_slot, cache) do
    cache
    |> Cluster.cluster_slots_tab()
    |> :ets.lookup(cache)
    |> Enum.reduce_while(nil, fn
      {_, start, stop, name}, _acc when hash_slot >= start and hash_slot <= stop ->
        index = Enum.random(0..(cache.__pool_size__ - 1))
        {:halt, :"#{name}_redix_#{index}"}

      _, acc ->
        {:cont, acc}
    end)
  end
end
