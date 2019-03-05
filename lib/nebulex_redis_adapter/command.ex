defmodule NebulexRedisAdapter.Command do
  # Redix command executor
  @moduledoc false

  alias NebulexRedisAdapter.Cluster

  @spec exec!(Nebulex.Cache.t(), Redix.command(), Nebulex.Cache.key()) :: any | no_return
  def exec!(cache, command, key \\ nil) do
    cache
    |> conn(key)
    |> Redix.command(command)
    |> handle_command_response(cache)
  end

  @spec pipeline!(Nebulex.Cache.t(), [Redix.command()], Nebulex.Cache.key()) :: [any] | no_return
  def pipeline!(cache, commands, key \\ nil) do
    cache
    |> conn(key)
    |> Redix.pipeline(commands)
    |> handle_command_response(cache)
  end

  @spec handle_command_response({:ok, any} | {:error, any}, Nebulex.Cache.t()) :: any | no_return
  def handle_command_response({:ok, response}, _cache) do
    response
  end

  def handle_command_response({:error, %Redix.Error{message: "MOVED" <> _} = reason}, cache) do
    :ok =
      cache
      |> Process.whereis()
      |> cache.stop()

    raise reason
  end

  def handle_command_response({:error, reason}, _cache) do
    raise reason
  end

  @spec get_conn(Nebulex.Cache.t(), atom) :: atom
  def get_conn(cache, name \\ nil) do
    prefix = name || cache
    index = rem(System.unique_integer([:positive]), cache.__pool_size__)
    :"#{prefix}_redix_#{index}"
  end

  ## Private Functions

  defp conn(cache, key) do
    conn(cache, key, cache.cluster_enabled?)
  end

  defp conn(cache, _key, false) do
    get_conn(cache)
  end

  defp conn(cache, key, true) do
    key
    |> cache.keyslot()
    |> cluster_slot_conn(cache)
  end

  defp cluster_slot_conn(hash_slot, cache) do
    cache
    |> Cluster.cluster_slots_tab()
    |> :ets.lookup(cache)
    |> Enum.reduce_while(nil, fn
      {_, start, stop, name}, _acc when hash_slot >= start and hash_slot <= stop ->
        {:halt, get_conn(cache, name)}

      _, acc ->
        {:cont, acc}
    end)
  end
end
