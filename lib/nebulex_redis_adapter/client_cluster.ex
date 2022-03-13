defmodule NebulexRedisAdapter.ClientCluster do
  # Client-side Cluster
  @moduledoc false

  alias NebulexRedisAdapter.ClientCluster.Keyslot, as: ClientClusterKeyslot
  alias NebulexRedisAdapter.ClientCluster.Supervisor, as: ClientClusterSupervisor
  alias NebulexRedisAdapter.Pool

  @typedoc "Proxy type to the adapter meta"
  @type adapter_meta :: Nebulex.Adapter.metadata()

  @type hash_slot :: {:"$hash_slot", term}
  @type node_entry :: {node_name :: atom, pool_size :: pos_integer}
  @type nodes_config :: [node_entry]

  ## API

  @spec init(adapter_meta, Keyword.t()) :: {Supervisor.child_spec(), adapter_meta}
  def init(%{name: name, registry: registry, pool_size: pool_size} = adapter_meta, opts) do
    node_connections_specs =
      for {node_name, node_opts} <- Keyword.get(opts, :nodes, []) do
        node_opts =
          node_opts
          |> Keyword.put(:name, name)
          |> Keyword.put(:registry, registry)
          |> Keyword.put(:node, node_name)
          |> Keyword.put_new(:pool_size, pool_size)

        Supervisor.child_spec({ClientClusterSupervisor, node_opts},
          type: :supervisor,
          id: {name, node_name}
        )
      end

    node_connections_supervisor_spec = %{
      id: :node_connections_supervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [node_connections_specs, [strategy: :one_for_one]]}
    }

    adapter_meta =
      Map.update(adapter_meta, :keyslot, ClientClusterKeyslot, &(&1 || ClientClusterKeyslot))

    {node_connections_supervisor_spec, adapter_meta}
  end

  @spec exec!(
          Nebulex.Adapter.adapter_meta(),
          Redix.command(),
          init_acc :: any,
          reducer :: (any, any -> any)
        ) :: any | no_return
  def exec!(
        %{name: name, registry: registry, nodes: nodes},
        command,
        init_acc \\ nil,
        reducer \\ fn res, _ -> res end
      ) do
    Enum.reduce(nodes, init_acc, fn {node_name, pool_size}, acc ->
      registry
      |> Pool.get_conn({name, node_name}, pool_size)
      |> Redix.command!(command)
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
