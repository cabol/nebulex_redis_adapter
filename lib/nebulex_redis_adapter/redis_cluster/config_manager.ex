defmodule NebulexRedisAdapter.RedisCluster.ConfigManager do
  @moduledoc false

  use GenServer

  import Nebulex.Helpers, only: [normalize_module_name: 1]
  import NebulexRedisAdapter.Helpers

  alias Nebulex.Telemetry
  alias NebulexRedisAdapter.RedisCluster
  alias NebulexRedisAdapter.RedisCluster.PoolSupervisor

  require Logger

  ## Internals

  # GenServer State
  defstruct adapter_meta: nil,
            opts: [],
            running_shards: [],
            dynamic_sup: nil,
            setup_retries: 1

  ## API

  @spec start_link({Nebulex.Adapter.adapter_meta(), keyword}) :: GenServer.on_start()
  def start_link({adapter_meta, opts}) do
    name = normalize_module_name([adapter_meta.name, ConfigManager])

    GenServer.start(__MODULE__, {adapter_meta, opts}, name: name)
  end

  @spec setup_shards(name :: atom) :: :ok
  def setup_shards(name) do
    [name, ConfigManager]
    |> normalize_module_name()
    |> GenServer.call(:setup_shards)
  end

  ## GenServer callbacks

  @impl true
  def init({adapter_meta, opts}) do
    state = %__MODULE__{
      adapter_meta: adapter_meta,
      opts: opts,
      dynamic_sup: normalize_module_name([adapter_meta.name, DynamicSupervisor])
    }

    {:ok, state, {:continue, :setup_shards}}
  end

  @impl true
  def handle_continue(:setup_shards, state) do
    do_setup_shards(state)
  end

  @impl true
  def handle_call(:setup_shards, from, state) do
    do_setup_shards(state, fn -> GenServer.reply(from, :ok) end)
  end

  @impl true
  def handle_info(message, state)

  def handle_info(:timeout, state) do
    do_setup_shards(state)
  end

  # coveralls-ignore-start

  def handle_info({:DOWN, ref, _type, pid, _reason}, %__MODULE__{running_shards: shards} = state) do
    if Enum.member?(shards, {pid, ref}) do
      do_setup_shards(state)
    else
      {:noreply, state}
    end
  end

  # coveralls-ignore-stop

  @impl true
  def terminate(_reason, %__MODULE__{adapter_meta: meta, dynamic_sup: sup, running_shards: lst}) do
    # Set cluster status to error
    :ok = RedisCluster.put_status(meta.name, :error)

    # Stop running shards/pools (cleanup)
    :ok = stop_running_shards(meta.cluster_shards_tab, sup, lst)
  end

  ## Private functions

  defp do_setup_shards(
         %__MODULE__{adapter_meta: %{name: name}, setup_retries: n} = state,
         on_locked \\ fn -> :noop end
       ) do
    # Lock the cluster
    :ok = RedisCluster.put_status(name, :locked)

    # Invoke the on_locked callback
    _ = on_locked.()

    # Configure the cluster shards/pools
    case configure_shards(state) do
      {:ok, running_shards} ->
        # Unlock the cluster (status set to ok)
        :ok = RedisCluster.put_status(name, :ok)

        {:noreply, %{state | running_shards: running_shards, setup_retries: 1}}

      {:error, reason} ->
        # Log the error
        :ok = Logger.error(fn -> "Error configuring cluster shards: #{inspect(reason)}" end)

        # Set cluster status to error
        :ok = RedisCluster.put_status(name, :error)

        {:noreply, %{state | running_shards: [], setup_retries: n + 1}, random_timeout(n)}
    end
  end

  defp configure_shards(%__MODULE__{
         adapter_meta: adapter_meta,
         opts: opts,
         dynamic_sup: dynamic_sup,
         running_shards: running_shards
       }) do
    metadata = %{
      adapter_meta: adapter_meta,
      pid: self(),
      status: nil,
      reason: nil
    }

    Telemetry.span(adapter_meta.telemetry_prefix ++ [:config_manager, :setup], metadata, fn ->
      case configure_shards(adapter_meta, dynamic_sup, running_shards, opts) do
        {:ok, _} = ok ->
          {ok, %{metadata | status: :ok, reason: :succeeded}}

        {:error, reason} ->
          # Wrap up the error
          error =
            wrap_error NebulexRedisAdapter.Error,
              reason: {:redis_cluster_setup_error, reason},
              cache: adapter_meta.name

          {error, %{metadata | status: :error, reason: reason}}
      end
    end)
  end

  defp configure_shards(
         %{
           cluster_shards_tab: cluster_shards_tab,
           registry: registry,
           pool_size: pool_size
         },
         dynamic_sup,
         running_shards,
         opts
       ) do
    # Stop running shards/pools (cleanup)
    :ok = stop_running_shards(cluster_shards_tab, dynamic_sup, running_shards)

    # Setup the cluster
    with {:ok, specs, conn_opts} <- get_cluster_shards(opts) do
      running_shards =
        Enum.map(specs, fn {start, stop, m_host, m_port} ->
          # Define slot id
          slot_id = {:cluster_shards, start, stop}

          # Define options
          opts =
            Keyword.merge(opts,
              conn_opts: conn_opts,
              slot_id: slot_id,
              registry: registry,
              pool_size: pool_size,
              master_host: m_host,
              master_port: m_port
            )

          # Define child spec
          shard_spec =
            Supervisor.child_spec(
              {PoolSupervisor, opts},
              type: :supervisor,
              id: {PoolSupervisor, slot_id},
              restart: :temporary
            )

          # Start the child for the given shard/pool
          {:ok, pid} = DynamicSupervisor.start_child(dynamic_sup, shard_spec)

          # Monitor the process
          ref = Process.monitor(pid)

          # Update hash slot map with the started one
          true = :ets.insert(cluster_shards_tab, slot_id)

          # Return the child pid with its monitor reference.
          {pid, ref}
        end)

      # Return running shards/pools
      {:ok, running_shards}
    end
  end

  defp stop_running_shards(cluster_shards_tab, dynamic_sup, running_shards) do
    # Flush the hash slot map
    true = :ets.delete(cluster_shards_tab, :cluster_shards)

    # Stop the running shards/pools
    Enum.each(running_shards, &DynamicSupervisor.terminate_child(dynamic_sup, elem(&1, 0)))
  end

  defp get_cluster_shards(opts) do
    endpoints =
      opts
      |> Keyword.fetch!(:redis_cluster)
      |> Keyword.fetch!(:configuration_endpoints)

    Enum.reduce_while(endpoints, nil, fn {_name, conn_opts}, _acc ->
      with {:ok, conn, config_endpoint} <- connect(conn_opts),
           {:ok, cluster_info} <- cluster_info(conn) do
        {:halt, {:ok, parse_cluster_info(cluster_info, config_endpoint, opts), conn_opts}}
      else
        error -> {:cont, error}
      end
    end)
  end

  defp connect(conn_opts) do
    conn_opts =
      conn_opts
      |> Keyword.delete(:sync_connect)
      |> Keyword.delete(:exit_on_disconnection)

    case Keyword.pop(conn_opts, :url) do
      {nil, conn_opts} ->
        with {:ok, conn} <- Redix.start_link(conn_opts) do
          {:ok, conn, conn_opts[:host]}
        end

      {url, conn_opts} ->
        with {:ok, conn} <- Redix.start_link(url, conn_opts) do
          {:ok, conn, URI.parse(url).host}
        end
    end
  end

  defp cluster_info(conn) do
    with {:error, %Redix.Error{}} <- Redix.command(conn, ["CLUSTER", "SHARDS"]) do
      Redix.command(conn, ["CLUSTER", "SLOTS"])
    end
  after
    Redix.stop(conn)
  end

  defp parse_cluster_info(config, config_endpoint, opts) do
    # Whether the given master host should be overridden with the
    # configuration endpoint or not
    override? =
      opts
      |> Keyword.fetch!(:redis_cluster)
      |> Keyword.fetch!(:override_master_host)

    Enum.reduce(config, [], fn
      # Redis version >= 7 (["CLUSTER", "SHARDS"])
      ["slots", slot_ranges, "nodes", nodes], acc ->
        case parse_node_attrs(nodes) do
          [] ->
            # coveralls-ignore-start
            acc

          # coveralls-ignore-stop

          [attrs | _] ->
            host = attrs["endpoint"]
            port = attrs["tls-port"] || attrs["port"]

            slot_ranges
            |> Enum.chunk_every(2)
            |> Enum.reduce(acc, fn [start, stop], acc ->
              [{start, stop, host, port} | acc]
            end)
        end

      # Redis version < 7 (["CLUSTER", "SLOTS"])
      [start, stop, [host, port | _tail] = _master | _replicas], acc ->
        [{start, stop, host, port} | acc]
    end)
    |> Enum.map(fn {start, stop, host, port} ->
      {maybe_convert_to_integer(start), maybe_convert_to_integer(stop),
       maybe_override_host(host, config_endpoint, override?), port}
    end)
  end

  defp parse_node_attrs(nodes) do
    Enum.reduce(nodes, [], fn attrs, acc ->
      attrs =
        attrs
        |> Enum.chunk_every(2)
        |> Enum.reduce(%{}, fn [key, value], acc ->
          Map.put(acc, key, value)
        end)

      [attrs | acc]
    end)
    |> Enum.filter(&(&1["role"] == "master" and &1["health"] == "online"))
  end

  defp maybe_override_host(_host, config_endpoint, true) do
    config_endpoint
  end

  # coveralls-ignore-start

  defp maybe_override_host(nil, config_endpoint, _override?) do
    config_endpoint
  end

  defp maybe_override_host(host, _config_endpoint, _override?) do
    host
  end

  defp maybe_convert_to_integer(value) when is_binary(value), do: String.to_integer(value)
  defp maybe_convert_to_integer(value), do: value

  # coveralls-ignore-stop
end
