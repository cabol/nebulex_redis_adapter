defmodule NebulexRedisAdapter.RedisCluster do
  # Redis Cluster Manager
  @moduledoc false

  import NebulexRedisAdapter.Helpers

  alias NebulexRedisAdapter.{Options, Pool}
  alias NebulexRedisAdapter.RedisCluster.Keyslot, as: RedisClusterKeyslot

  @typedoc "Proxy type to the adapter meta"
  @type adapter_meta :: Nebulex.Adapter.adapter_meta()

  # Redis cluster hash slots size
  @redis_cluster_hash_slots 16_384

  ## API

  @spec init(adapter_meta, Keyword.t()) :: {Supervisor.child_spec(), adapter_meta}
  def init(%{name: name} = adapter_meta, opts) do
    # Ensure :redis_cluster is provided
    if is_nil(Keyword.get(opts, :redis_cluster)) do
      raise ArgumentError,
            Options.invalid_cluster_config_error(
              "invalid value for :redis_cluster option: ",
              nil,
              :redis_cluster
            )
    end

    # Init ETS table to store the hash slot map
    cluster_shards_tab = init_hash_slot_map_table(name)

    # Update adapter meta
    adapter_meta =
      Map.merge(adapter_meta, %{
        cluster_shards_tab: cluster_shards_tab,
        keyslot: get_keyslot(opts)
      })

    children = [
      {NebulexRedisAdapter.RedisCluster.DynamicSupervisor, {adapter_meta, opts}},
      {NebulexRedisAdapter.RedisCluster.ConfigManager, {adapter_meta, opts}}
    ]

    cluster_shards_supervisor_spec = %{
      id: {name, RedisClusterSupervisor},
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :rest_for_one]]}
    }

    {cluster_shards_supervisor_spec, adapter_meta}
  end

  @spec exec!(adapter_meta, Redix.command(), Keyword.t(), init_acc :: any, (any, any -> any)) ::
          any
  def exec!(
        %{
          name: name,
          cluster_shards_tab: cluster_shards_tab,
          registry: registry,
          pool_size: pool_size
        },
        command,
        opts,
        init_acc \\ nil,
        reducer \\ fn res, _ -> res end
      ) do
    with_retry(name, Keyword.get(opts, :lock_retries, :infinity), fn ->
      cluster_shards_tab
      |> :ets.lookup(:cluster_shards)
      |> Enum.reduce(init_acc, fn slot_id, acc ->
        registry
        |> Pool.get_conn(slot_id, pool_size)
        |> Redix.command!(command, redis_command_opts(opts))
        |> reducer.(acc)
      end)
    end)
  end

  @spec get_conn(adapter_meta, {:"$hash_slot", any} | any, Keyword.t()) :: pid | nil
  def get_conn(
        %{
          name: name,
          keyslot: keyslot,
          cluster_shards_tab: cluster_shards_tab,
          registry: registry,
          pool_size: pool_size
        },
        key,
        opts
      ) do
    with_retry(name, Keyword.get(opts, :lock_retries, :infinity), fn ->
      {:"$hash_slot", hash_slot} =
        case key do
          {:"$hash_slot", _} ->
            key

          _ ->
            hash_slot(key, keyslot)
        end

      cluster_shards_tab
      |> :ets.lookup(:cluster_shards)
      |> Enum.reduce_while(nil, fn
        {_, start, stop} = slot_id, _acc when hash_slot >= start and hash_slot <= stop ->
          {:halt, Pool.get_conn(registry, slot_id, pool_size)}

        _, acc ->
          {:cont, acc}
      end)
    end)
  end

  @spec group_keys_by_hash_slot(Enum.t(), module, atom()) :: map
  def group_keys_by_hash_slot(enum, keyslot, :keys) do
    Enum.group_by(enum, &hash_slot(&1, keyslot))
  end

  def group_keys_by_hash_slot(enum, keyslot, :tuples) do
    Enum.group_by(enum, fn {key, _} -> hash_slot(key, keyslot) end)
  end

  @spec hash_slot(any, module) :: {:"$hash_slot", pos_integer}
  def hash_slot(key, keyslot \\ RedisClusterKeyslot) do
    {:"$hash_slot", keyslot.hash_slot(key, @redis_cluster_hash_slots)}
  end

  @spec get_status(atom, atom) :: atom
  def get_status(name, default \\ :locked) when is_atom(name) and is_atom(default) do
    name
    |> status_key()
    |> :persistent_term.get(default)
  end

  @spec put_status(atom, atom) :: :ok
  def put_status(name, status) when is_atom(name) and is_atom(status) do
    # An atom is a single word so this does not trigger a global GC
    name
    |> status_key()
    |> :persistent_term.put(status)
  end

  @spec del_status_key(atom) :: boolean
  def del_status_key(name) when is_atom(name) do
    # An atom is a single word so this does not trigger a global GC
    name
    |> status_key()
    |> :persistent_term.erase()
  end

  @spec with_retry(atom, pos_integer, (-> term)) :: term
  def with_retry(name, retries, fun) do
    with_retry(name, fun, retries, 1)
  end

  # coveralls-ignore-start

  defp with_retry(_name, fun, max_retries, retries) when retries >= max_retries do
    fun.()
  end

  # coveralls-ignore-stop

  defp with_retry(name, fun, max_retries, retries) do
    case get_status(name) do
      :ok ->
        fun.()

      :locked ->
        :ok = random_sleep(retries)

        with_retry(name, fun, max_retries, retries + 1)

      :error ->
        raise NebulexRedisAdapter.Error, reason: :redis_cluster_status_error, cache: name
    end
  end

  ## Private Functions

  # Inline common instructions
  @compile {:inline, status_key: 1}

  defp status_key(name), do: {name, :redis_cluster_status}

  defp init_hash_slot_map_table(name) do
    :ets.new(name, [
      :public,
      :duplicate_bag,
      read_concurrency: true
    ])
  end

  defp get_keyslot(opts) do
    opts
    |> Keyword.fetch!(:redis_cluster)
    |> Keyword.fetch!(:keyslot)
  end
end
