defmodule NebulexRedisAdapter.ClusterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest

  alias NebulexRedisAdapter.TestCache.Cluster, as: Cache

  setup do
    {:ok, pid} = Cache.start_link()
    Cache.flush()
    :ok

    on_exit(fn ->
      :ok = Process.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)

    {:ok, cache: Cache, name: Cache}
  end
end
