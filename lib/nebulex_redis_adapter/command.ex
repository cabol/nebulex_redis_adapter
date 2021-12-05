defmodule NebulexRedisAdapter.Command do
  # Redix command executor
  @moduledoc false

  alias NebulexRedisAdapter.{ClientCluster, Pool, RedisCluster}

  @spec exec!(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          Nebulex.Cache.key()
        ) :: any | no_return
  def exec!(adapter_meta, command, key \\ nil) do
    adapter_meta
    |> conn(key)
    |> Redix.command(command)
    |> handle_command_response()
  end

  @spec pipeline!(
          Nebulex.Adapter.adapter_meta(),
          [Redix.command()],
          Nebulex.Cache.key()
        ) :: [any] | no_return
  def pipeline!(adapter_meta, commands, key \\ nil) do
    adapter_meta
    |> conn(key)
    |> Redix.pipeline(commands)
    |> handle_command_response()
    |> check_pipeline_errors()
  end

  ## Private Functions

  defp conn(%{mode: :standalone, name: name, pool_size: pool_size}, _key) do
    Pool.get_conn(name, pool_size)
  end

  defp conn(%{mode: :client_side_cluster, name: name, nodes: nodes}, {:"$hash_slot", node_name}) do
    ClientCluster.get_conn(name, nodes, node_name)
  end

  defp conn(%{mode: :client_side_cluster, name: name, nodes: nodes, keyslot: keyslot}, key) do
    ClientCluster.get_conn(name, nodes, key, keyslot)
  end

  defp conn(%{mode: :redis_cluster} = meta, key) do
    RedisCluster.get_conn(meta, key)
  end

  defp handle_command_response({:ok, response}) do
    response
  end

  defp handle_command_response({:error, %Redix.Error{message: "MOVED" <> _} = error}) do
    raise error
  end

  defp handle_command_response({:error, reason}) do
    raise reason
  end

  defp check_pipeline_errors(results) do
    _ = for %Redix.Error{} = error <- results, do: raise(error)
    results
  end
end
