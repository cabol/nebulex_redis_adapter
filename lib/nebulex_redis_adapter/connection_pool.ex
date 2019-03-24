defmodule NebulexRedisAdapter.ConnectionPool do
  @moduledoc false

  @default_pool_size System.schedulers_online()

  ## API

  @spec children(atom, Keyword.t()) :: [Supervisor.child_spec]
  def children(name, opts) do
    {pool_size, opts} = pop_pool_size(opts)

    for i <- 0..(pool_size - 1) do
      opts = Keyword.put(opts, :name, :"#{name}_redix_#{i}")

      case Keyword.pop(opts, :url) do
        {nil, opts} ->
          Supervisor.child_spec({Redix, opts}, id: {Redix, i})

        {url, opts} ->
          Supervisor.child_spec({Redix, {url, opts}}, id: {Redix, i})
      end
    end
  end

  @spec get_conn(atom, integer) :: atom
  def get_conn(name, pool_size) do
    index = rem(System.unique_integer([:positive]), pool_size)
    :"#{name}_redix_#{index}"
  end

  ## Private Functions

  defp pop_pool_size(opts) do
    case Keyword.pop(opts, :pool_size) do
      {nil, opts} -> {@default_pool_size, opts}
      {_, _} = rs -> rs
    end
  end
end
