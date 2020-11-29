defmodule NebulexRedisAdapter.Pool do
  @moduledoc false

  ## API

  @spec children(module, Keyword.t()) :: [Supervisor.child_spec()]
  def children(module, opts) do
    name = Keyword.fetch!(opts, :name)
    pool_size = opts[:pool_size] || System.schedulers_online()

    for index <- 0..(pool_size - 1) do
      opts = Keyword.put(opts, :name, :"#{name}.#{index}")
      {module, opts}
    end
  end

  @spec get_conn(atom, pos_integer) :: atom
  def get_conn(name, pool_size) do
    # ensure to select the same connection based on the caller PID
    :"#{name}.#{:erlang.phash2(self(), pool_size)}"
  end
end
