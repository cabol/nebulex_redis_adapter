defmodule NebulexRedisAdapter.Cluster.NodeSupervisor do
  @moduledoc """
  Node Supervisor.
  """

  use Supervisor

  alias NebulexRedisAdapter.ConnectionPool

  ## API

  @doc false
  def start_link({name, opts}) do
    Supervisor.start_link(__MODULE__, {name, opts}, name: name)
  end

  ## Supervisor Callbacks

  @impl true
  def init({name, opts}) do
    name
    |> ConnectionPool.children(opts)
    |> Supervisor.init(strategy: :one_for_one)
  end
end
