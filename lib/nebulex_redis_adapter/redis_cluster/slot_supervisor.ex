defmodule NebulexRedisAdapter.RedisCluster.SlotSupervisor do
  @moduledoc """
  Redis Cluster Slot Supervisor.
  """

  use Supervisor

  ## API

  @doc false
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, {name, opts}, name: name)
  end

  ## Supervisor Callbacks

  @impl true
  def init({name, opts}) do
    cluster = Keyword.fetch!(opts, :cluster)
    pool_size = Keyword.fetch!(opts, :pool_size)
    [[host, port, _id] = _master | _replicas] = Keyword.fetch!(opts, :nodes)

    conn_opts =
      opts
      |> Keyword.get(:redix_opts, [])
      |> Keyword.delete(:url)
      |> Keyword.put(:host, Keyword.get(cluster, :global_host) || host)
      |> Keyword.put(:port, port)

    children =
      for i <- 0..(pool_size - 1) do
        conn_opts = Keyword.put(conn_opts, :name, :"#{name}_redix_#{i}")
        Supervisor.child_spec({Redix, conn_opts}, id: {Redix, i})
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
