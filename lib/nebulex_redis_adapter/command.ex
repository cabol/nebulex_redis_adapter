defmodule NebulexRedisAdapter.Command do
  # Redix command executor
  @moduledoc false

  @spec exec!(Nebulex.Cache.t(), Redix.command()) :: any | no_return
  def exec!(cache, command) do
    cache
    |> get_conn()
    |> Redix.command!(command)
  end

  @spec pipeline!(Nebulex.Cache.t(), [Redix.command()]) :: [any] | no_return
  def pipeline!(cache, command) do
    cache
    |> get_conn()
    |> Redix.pipeline!(command)
  end

  defp get_conn(cache) do
    index = rem(System.unique_integer([:positive]), cache.__pool_size__)
    :"#{cache}_redix_#{index}"
  end
end
