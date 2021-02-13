defmodule NebulexRedisAdapter.ClientCluster.Supervisor do
  @moduledoc false
  use Supervisor

  alias NebulexRedisAdapter.Pool

  ## API

  @doc false
  def start_link({module, opts}) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, {module, opts}, name: name)
  end

  ## Supervisor Callbacks

  @impl true
  def init({module, opts}) do
    module
    |> Pool.children(opts)
    |> Supervisor.init(strategy: :one_for_one)
  end
end
