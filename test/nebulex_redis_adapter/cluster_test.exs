defmodule NebulexRedisAdapter.ClusterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest, cache: NebulexRedisAdapter.TestCache.Cluster

  alias NebulexRedisAdapter.TestCache.Cluster, as: Cache

  setup do
    {:ok, pid} = Cache.start_link()
    Cache.flush()
    :ok

    on_exit(fn ->
      _ = :timer.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)
  end
end
