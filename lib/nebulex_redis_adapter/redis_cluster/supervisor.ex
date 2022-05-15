defmodule NebulexRedisAdapter.RedisCluster.Supervisor do
  @moduledoc """
  Redis Cluster Node/Slot Supervisor.
  """

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
    slot_id = Keyword.fetch!(opts, :slot_id)
    registry = Keyword.fetch!(opts, :registry)
    pool_size = Keyword.fetch!(opts, :pool_size)

    [[host, port | _tail] = _master | _replicas] = Keyword.fetch!(opts, :nodes)

    conn_opts =
      opts
      |> Keyword.get(:conn_opts, [])
      |> Keyword.delete(:url)
      |> Keyword.put_new(:host, host)
      |> Keyword.put_new(:port, port)

    children =
      Pool.register_names(registry, slot_id, pool_size, fn conn_name ->
        conn_opts = Keyword.put(conn_opts, :name, conn_name)

        Supervisor.child_spec({Redix, conn_opts}, id: {Redix, conn_name})
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
