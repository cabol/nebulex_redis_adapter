defmodule NebulexRedisAdapter.RedisCluster.DynamicSupervisor do
  @moduledoc false

  use DynamicSupervisor

  import Nebulex.Helpers, only: [normalize_module_name: 1]

  ## API

  @spec start_link({Nebulex.Adapter.adapter_meta(), keyword}) :: Supervisor.on_start()
  def start_link({adapter_meta, opts}) do
    name = normalize_module_name([adapter_meta.name, DynamicSupervisor])

    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  ## Callbacks

  @impl true
  def init(opts) do
    max_children = Keyword.get(opts, :max_children, :infinity)

    DynamicSupervisor.init(strategy: :one_for_one, max_children: max_children)
  end
end
