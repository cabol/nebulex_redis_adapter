defmodule NebulexRedisAdapter.Command do
  # Redix command executor
  @moduledoc false

  alias NebulexRedisAdapter.{ClientCluster, Pool, RedisCluster}

  ## API

  @doc """
  Executes a Redis command.
  """
  @spec exec(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          Nebulex.Cache.key()
        ) :: {:ok, term} | {:error, term}
  def exec(adapter_meta, command, key \\ nil) do
    adapter_meta
    |> conn(key)
    |> Redix.command(command)
  end

  @doc """
  Executes a Redis command, but raises an exception if an error occurs.
  """
  @spec exec!(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          Nebulex.Cache.key()
        ) :: term
  def exec!(adapter_meta, command, key \\ nil) do
    adapter_meta
    |> conn(key)
    |> Redix.command(command)
    |> handle_command_response()
  end

  @doc """
  Executes a Redis pipeline.
  """
  @spec pipeline(
          Nebulex.Adapter.adapter_meta(),
          [Redix.command()],
          Nebulex.Cache.key()
        ) :: {:ok, [term]} | {:error, term}
  def pipeline(adapter_meta, commands, key \\ nil) do
    adapter_meta
    |> conn(key)
    |> Redix.pipeline(commands)
  end

  @doc """
  Executes a Redis pipeline, but raises an exception if an error occurs.
  """
  @spec pipeline!(
          Nebulex.Adapter.adapter_meta(),
          [Redix.command()],
          Nebulex.Cache.key()
        ) :: [term]
  def pipeline!(adapter_meta, commands, key \\ nil) do
    adapter_meta
    |> conn(key)
    |> Redix.pipeline(commands)
    |> handle_command_response()
    |> check_pipeline_errors()
  end

  ## Private Functions

  defp conn(%{mode: :standalone, name: name, registry: registry, pool_size: pool_size}, _key) do
    Pool.get_conn(registry, name, pool_size)
  end

  defp conn(%{mode: :redis_cluster} = meta, key) do
    RedisCluster.get_conn(meta, key)
  end

  defp conn(
         %{mode: :client_side_cluster, name: name, registry: registry, nodes: nodes},
         {:"$hash_slot", node_name}
       ) do
    ClientCluster.get_conn(registry, name, nodes, node_name)
  end

  defp conn(
         %{
           mode: :client_side_cluster,
           name: name,
           registry: registry,
           nodes: nodes,
           keyslot: keyslot
         },
         key
       ) do
    ClientCluster.get_conn(registry, name, nodes, key, keyslot)
  end

  defp handle_command_response({:ok, response}) do
    response
  end

  defp handle_command_response({:error, reason}) do
    raise reason
  end

  defp check_pipeline_errors(results) do
    Enum.map(results, fn
      %Redix.Error{} = error -> raise error
      result -> result
    end)
  end
end
