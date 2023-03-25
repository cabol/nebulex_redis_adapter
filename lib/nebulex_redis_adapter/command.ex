defmodule NebulexRedisAdapter.Command do
  # Redix command executor
  @moduledoc false

  import NebulexRedisAdapter.Helpers

  alias NebulexRedisAdapter.{
    ClientCluster,
    Pool,
    RedisCluster,
    RedisCluster.ConfigManager
  }

  ## API

  @doc """
  Executes a Redis command.
  """
  @spec exec(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          Nebulex.Cache.key(),
          Keyword.t()
        ) :: {:ok, term} | {:error, term}
  def exec(adapter_meta, command, key \\ nil, opts \\ []) do
    adapter_meta
    |> conn(key, opts)
    |> Redix.command(command, redis_command_opts(opts))
  end

  @doc """
  Executes a Redis command, but raises an exception if an error occurs.
  """
  @spec exec!(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          Nebulex.Cache.key(),
          Keyword.t()
        ) :: term
  def exec!(adapter_meta, command, key \\ nil, opts \\ [])

  def exec!(%{mode: :redis_cluster, name: name} = adapter_meta, command, key, opts) do
    on_moved = fn ->
      # Re-configure the cluster
      :ok = ConfigManager.setup_shards(name)

      # Retry once more
      do_exec!(adapter_meta, command, key, opts, nil)
    end

    do_exec!(adapter_meta, command, key, opts, on_moved)
  end

  def exec!(adapter_meta, command, key, opts) do
    do_exec!(adapter_meta, command, key, opts, nil)
  end

  defp do_exec!(adapter_meta, command, key, opts, on_moved) do
    adapter_meta
    |> conn(key, opts)
    |> Redix.command(command, redis_command_opts(opts))
    |> handle_command_response(on_moved)
  end

  @doc """
  Executes a Redis pipeline.
  """
  @spec pipeline(
          Nebulex.Adapter.adapter_meta(),
          [Redix.command()],
          Nebulex.Cache.key(),
          Keyword.t()
        ) :: {:ok, [term]} | {:error, term}
  def pipeline(adapter_meta, commands, key \\ nil, opts \\ []) do
    adapter_meta
    |> conn(key, opts)
    |> Redix.pipeline(commands, redis_command_opts(opts))
  end

  @doc """
  Executes a Redis pipeline, but raises an exception if an error occurs.
  """
  @spec pipeline!(
          Nebulex.Adapter.adapter_meta(),
          [Redix.command()],
          Nebulex.Cache.key(),
          Keyword.t()
        ) :: [term]
  def pipeline!(adapter_meta, commands, key \\ nil, opts \\ [])

  def pipeline!(%{mode: :redis_cluster, name: name} = adapter_meta, commands, key, opts) do
    on_moved = fn ->
      # Re-configure the cluster
      :ok = ConfigManager.setup_shards(name)

      # Retry once more
      do_pipeline!(adapter_meta, commands, key, opts, nil)
    end

    do_pipeline!(adapter_meta, commands, key, opts, on_moved)
  end

  def pipeline!(adapter_meta, commands, key, opts) do
    do_pipeline!(adapter_meta, commands, key, opts, nil)
  end

  defp do_pipeline!(adapter_meta, commands, key, opts, on_moved) do
    adapter_meta
    |> conn(key, opts)
    |> Redix.pipeline(commands, redis_command_opts(opts))
    |> handle_command_response(on_moved)
    |> check_pipeline_errors(on_moved)
  end

  ## Private Functions

  defp conn(
         %{mode: :standalone, name: name, registry: registry, pool_size: pool_size},
         _key,
         _opts
       ) do
    Pool.get_conn(registry, name, pool_size)
  end

  defp conn(%{mode: :redis_cluster, name: name} = meta, key, opts) do
    with nil <- RedisCluster.get_conn(meta, key, opts) do
      # Perhars the cluster has to be re-configured again
      :ok = ConfigManager.setup_shards(name)

      # Retry once more
      RedisCluster.get_conn(meta, key, opts)
    end
  end

  defp conn(
         %{mode: :client_side_cluster, name: name, registry: registry, nodes: nodes},
         {:"$hash_slot", node_name},
         _opts
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
         key,
         _opts
       ) do
    ClientCluster.get_conn(registry, name, nodes, key, keyslot)
  end

  defp handle_command_response({:ok, response}, _on_moved) do
    response
  end

  defp handle_command_response({:error, %Redix.Error{message: "MOVED" <> _}}, on_moved)
       when is_function(on_moved) do
    on_moved.()
  end

  defp handle_command_response({:error, reason}, _on_moved) do
    raise reason
  end

  defp check_pipeline_errors(results, on_moved) do
    Enum.map(results, fn
      %Redix.Error{} = error ->
        handle_command_response({:error, error}, on_moved)

      result ->
        result
    end)
  end
end
