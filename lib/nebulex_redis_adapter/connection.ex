defmodule NebulexRedisAdapter.Connection do
  @moduledoc false

  alias NebulexRedisAdapter.Pool

  @typedoc "Proxy type to the adapter meta"
  @type adapter_meta :: Nebulex.Adapter.metadata()

  ## API

  @spec init(adapter_meta, Keyword.t()) :: {Supervisor.child_spec(), adapter_meta}
  def init(%{name: name, registry: registry, pool_size: pool_size} = adapter_meta, opts) do
    connections_specs =
      Pool.register_names(registry, name, pool_size, fn conn_name ->
        opts
        |> Keyword.put(:name, conn_name)
        |> child_spec()
      end)

    connections_supervisor_spec = %{
      id: :connections_supervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [connections_specs, [strategy: :one_for_one]]}
    }

    {connections_supervisor_spec, adapter_meta}
  end

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: {Redix, name},
      type: :worker,
      start: {Redix, :start_link, redix_args(name, opts)}
    }
  end

  @spec conn_opts(Keyword.t()) :: Keyword.t()
  def conn_opts(opts) do
    Keyword.get(opts, :conn_opts, host: "127.0.0.1", port: 6379)
  end

  ## Private Functions

  defp redix_args(name, opts) do
    conn_opts =
      opts
      |> conn_opts()
      |> Keyword.put(:name, name)

    case Keyword.pop(conn_opts, :url) do
      {nil, conn_opts} -> [conn_opts]
      {url, conn_opts} -> [url, conn_opts]
    end
  end
end
