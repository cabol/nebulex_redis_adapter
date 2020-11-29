defmodule NebulexRedisAdapter.Command do
  # Redix command executor
  @moduledoc false

  alias NebulexRedisAdapter.{Cluster, Pool, RedisCluster}

  @spec exec!(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          Nebulex.Cache.key()
        ) :: any | no_return
  def exec!(%{cache: cache} = meta, command, key \\ nil) do
    meta
    |> conn(key)
    |> Redix.command(command)
    |> handle_command_response(cache)
  end

  @spec pipeline!(
          Nebulex.Adapter.adapter_meta(),
          [Redix.command()],
          Nebulex.Cache.key()
        ) :: [any] | no_return
  def pipeline!(%{cache: cache} = meta, commands, key \\ nil) do
    meta
    |> conn(key)
    |> Redix.pipeline(commands)
    |> handle_command_response(cache)
  end

  @spec handle_command_response({:ok, any} | {:error, any}, Nebulex.Cache.t()) :: any | no_return
  def handle_command_response({:ok, response}, _cache) do
    response
  end

  def handle_command_response({:error, %Redix.Error{message: "MOVED" <> _} = error}, cache) do
    :ok = cache.stop()
    raise error
  end

  def handle_command_response({:error, reason}, _cache) do
    raise reason
  end

  ## Private Functions

  defp conn(%{mode: :standalone, name: name, pool_size: pool_size}, _key) do
    Pool.get_conn(name, pool_size)
  end

  defp conn(%{mode: :cluster, name: name, nodes: nodes}, {:"$hash_slot", node_name}) do
    Cluster.get_conn(name, nodes, node_name)
  end

  defp conn(%{mode: :cluster, name: name, nodes: nodes, keyslot: keyslot}, key) do
    Cluster.get_conn(name, nodes, key, keyslot)
  end

  defp conn(%{mode: :redis_cluster} = meta, key) do
    RedisCluster.get_conn(meta, key)
  end
end
