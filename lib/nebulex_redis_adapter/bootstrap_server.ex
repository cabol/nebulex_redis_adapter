defmodule NebulexRedisAdapter.BootstrapServer do
  @moduledoc """
  This server takes care of initialization and cleanup jobs. For example,
  attaching the stats handler when the cache starts and detaching it when
  it terminates.
  """
  use GenServer

  import Nebulex.Helpers

  alias Nebulex.Telemetry
  alias Nebulex.Telemetry.StatsHandler
  alias NebulexRedisAdapter.RedisCluster

  ## API

  @spec start_link(Nebulex.Adapter.adapter_meta()) :: GenServer.on_start()
  def start_link(adapter_meta) do
    name = normalize_module_name([Map.fetch!(adapter_meta, :name), BootstrapServer])

    GenServer.start_link(__MODULE__, adapter_meta, name: name)
  end

  ## GenServer Callbacks

  @impl true
  def init(adapter_meta) do
    _ = Process.flag(:trap_exit, true)

    {:ok, adapter_meta, {:continue, :attach_stats_handler}}
  end

  @impl true
  def handle_continue(:attach_stats_handler, adapter_meta) do
    _ = maybe_attach_stats_handler(adapter_meta)

    {:noreply, adapter_meta}
  end

  @impl true
  def terminate(_reason, adapter_meta) do
    _ = if ref = adapter_meta.stats_counter, do: Telemetry.detach(ref)

    if adapter_meta.mode == :redis_cluster do
      RedisCluster.del_status_key(adapter_meta.name)
    end
  end

  ## Private Functions

  defp maybe_attach_stats_handler(adapter_meta) do
    if ref = adapter_meta.stats_counter do
      Telemetry.attach_many(
        ref,
        [adapter_meta.telemetry_prefix ++ [:command, :stop]],
        &StatsHandler.handle_event/4,
        ref
      )
    end
  end
end
