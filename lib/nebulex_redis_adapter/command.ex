defmodule NebulexRedisAdapter.Command do
  # Redix command executor
  @moduledoc false

  alias NebulexCluster.Pool
  alias NebulexRedisAdapter.RedisCluster

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

  ## Private Functions

  defp conn(cache, key) do
    conn(cache, key, cache.__mode__)
  end

  defp conn(cache, _key, :standalone) do
    Pool.get_conn(cache, cache.__pool_size__)
  end

  defp conn(cache, {:"$hash_slot", node_name}, :cluster) do
    NebulexCluster.get_conn(cache, cache.__nodes__, node_name)
  end

  defp conn(cache, key, :cluster) do
    NebulexCluster.get_conn(cache, cache.__nodes__, key, cache.__hash_slot__)
  end

  defp conn(cache, key, :redis_cluster) do
    RedisCluster.get_conn(cache, key)
  end
end
