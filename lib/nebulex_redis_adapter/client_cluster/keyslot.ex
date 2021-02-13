defmodule NebulexRedisAdapter.ClientCluster.Keyslot do
  @moduledoc """
  Default Keyslot implementation when `:jchash` module is loaded.
  """
  use Nebulex.Adapter.Keyslot

  if Code.ensure_loaded?(:jchash) do
    @impl true
    def hash_slot(key, range) do
      key
      |> :erlang.phash2()
      |> :jchash.compute(range)
    end
  end
end
