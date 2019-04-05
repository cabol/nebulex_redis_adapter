defmodule NebulexRedisAdapter.Connection do
  @moduledoc false

  ## API

  @spec init(Keyword.t()) :: {:ok, [Supervisor.child_spec()]}
  def init(opts) do
    cache = Keyword.fetch!(opts, :cache)

    children =
      for i <- 0..(cache.__pool_size__ - 1) do
        child_spec([name: :"#{cache}.#{i}"] ++ opts)
      end

    {:ok, children}
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
