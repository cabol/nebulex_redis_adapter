defmodule NebulexRedisAdapter.Pool do
  @moduledoc false

  ## API

  @spec register_names(atom, term, pos_integer, ({:via, module, term} -> term)) :: [term]
  def register_names(registry, key, pool_size, fun) do
    for index <- 0..(pool_size - 1) do
      fun.({:via, Registry, {registry, {key, index}}})
    end
  end

  @spec get_conn(atom, term, pos_integer) :: pid
  def get_conn(registry, key, pool_size) do
    # Ensure selecting the same connection based on the caller PID
    index = :erlang.phash2(self(), pool_size)

    registry
    |> Registry.lookup({key, index})
    |> hd()
    |> elem(0)
  end
end
