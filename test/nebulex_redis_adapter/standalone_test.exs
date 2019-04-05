defmodule NebulexRedisAdapter.StandaloneTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest, cache: NebulexRedisAdapter.TestCache.Standalone

  alias NebulexRedisAdapter.Command
  alias NebulexRedisAdapter.TestCache.Standalone, as: Cache

  setup do
    {:ok, pid} = Cache.start_link()
    Cache.flush()
    :ok

    on_exit(fn ->
      _ = :timer.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)
  end

  test "command error" do
    assert_raise Redix.Error, fn ->
      Command.exec!(Cache, ["INCRBY", "counter", "invalid"])
    end
  end
end
