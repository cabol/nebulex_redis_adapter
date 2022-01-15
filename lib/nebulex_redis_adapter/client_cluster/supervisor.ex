defmodule NebulexRedisAdapter.ClientCluster.Supervisor do
  @moduledoc false
  use Supervisor

  alias NebulexRedisAdapter.Pool

  ## API

  @doc false
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  ## Supervisor Callbacks

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    registry = Keyword.fetch!(opts, :registry)
    node = Keyword.fetch!(opts, :node)
    pool_size = Keyword.fetch!(opts, :pool_size)

    children =
      Pool.register_names(registry, {name, node}, pool_size, fn conn_name ->
        {NebulexRedisAdapter.Connection, Keyword.put(opts, :name, conn_name)}
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
