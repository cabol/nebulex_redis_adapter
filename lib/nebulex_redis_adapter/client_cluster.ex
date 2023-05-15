defmodule NebulexRedisAdapter.ClientCluster do
  # Client-side Cluster
  @moduledoc false

  import NebulexRedisAdapter.Helpers

  alias NebulexRedisAdapter.ClientCluster.Supervisor, as: ClientClusterSupervisor
  alias NebulexRedisAdapter.{Options, Pool}

  @typedoc "Proxy type to the adapter meta"
  @type adapter_meta :: Nebulex.Adapter.metadata()

  @type hash_slot :: {:"$hash_slot", term}
  @type node_entry :: {node_name :: atom, pool_size :: pos_integer}
  @type nodes_config :: [node_entry]

  ## API

  @spec init(adapter_meta, Keyword.t()) :: {Supervisor.child_spec(), adapter_meta}
  def init(%{name: name, registry: registry, pool_size: pool_size} = adapter_meta, opts) do
    cluster_opts = Keyword.get(opts, :client_side_cluster)

    # Ensure :client_side_cluster is provided
    if is_nil(cluster_opts) do
      raise ArgumentError,
            Options.invalid_cluster_config_error(
              "invalid value for :client_side_cluster option: ",
              nil,
              :client_side_cluster
            )
    end

    {node_connections_specs, nodes} =
      cluster_opts
      |> Keyword.fetch!(:nodes)
      |> Enum.reduce({[], []}, fn {node_name, node_opts}, {acc1, acc2} ->
        node_opts =
          node_opts
          |> Keyword.put(:name, name)
          |> Keyword.put(:registry, registry)
          |> Keyword.put(:node, node_name)
          |> Keyword.put_new(:pool_size, pool_size)

        child_spec =
          Supervisor.child_spec({ClientClusterSupervisor, node_opts},
            type: :supervisor,
            id: {name, node_name}
          )

        {[child_spec | acc1], [{node_name, Keyword.fetch!(node_opts, :pool_size)} | acc2]}
      end)

    node_connections_supervisor_spec = %{
      id: :node_connections_supervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [node_connections_specs, [strategy: :one_for_one]]}
    }

    # Update adapter meta
    adapter_meta =
      Map.merge(adapter_meta, %{
        nodes: nodes,
        keyslot: Keyword.fetch!(cluster_opts, :keyslot)
      })

    {node_connections_supervisor_spec, adapter_meta}
  end

  @spec exec!(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          Keyword.t(),
          init_acc :: any,
          reducer :: (any, any -> any)
        ) :: any | no_return
  def exec!(
        %{name: name, registry: registry, nodes: nodes},
        command,
        opts,
        init_acc \\ nil,
        reducer \\ fn res, _ -> res end
      ) do
    Enum.reduce(nodes, init_acc, fn {node_name, pool_size}, acc ->
      registry
      |> Pool.get_conn({name, node_name}, pool_size)
      |> Redix.command!(command, redis_command_opts(opts))
      |> reducer.(acc)
    end)
  end

  @spec get_conn(atom, atom, nodes_config, atom) :: pid
  def get_conn(registry, name, nodes, node_name) do
    pool_size = Keyword.fetch!(nodes, node_name)

    Pool.get_conn(registry, {name, node_name}, pool_size)
  end

  @spec get_conn(atom, atom, nodes_config, term, module) :: pid
  def get_conn(registry, name, nodes, key, module) do
    {node_name, pool_size} = get_node(module, nodes, key)

    Pool.get_conn(registry, {name, node_name}, pool_size)
  end

  @spec group_keys_by_hash_slot(Enum.t(), nodes_config, module) :: map
  def group_keys_by_hash_slot(enum, nodes, module) do
    Enum.reduce(enum, %{}, fn
      {key, _} = entry, acc ->
        hash_slot = hash_slot(module, key, nodes)

        Map.put(acc, hash_slot, [entry | Map.get(acc, hash_slot, [])])

      key, acc ->
        hash_slot = hash_slot(module, key, nodes)

        Map.put(acc, hash_slot, [key | Map.get(acc, hash_slot, [])])
    end)
  end

  ## Private Functions

  defp get_node(module, nodes, key) do
    index = module.hash_slot(key, length(nodes))

    Enum.at(nodes, index)
  end

  defp hash_slot(module, key, nodes) do
    node =
      module
      |> get_node(nodes, key)
      |> elem(0)

    {:"$hash_slot", node}
  end
end
