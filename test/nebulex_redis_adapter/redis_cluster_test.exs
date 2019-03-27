defmodule NebulexRedisAdapter.RedisClusterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest, cache: NebulexRedisAdapter.TestCache.RedisCluster

  alias NebulexRedisAdapter.RedisCluster
  alias NebulexRedisAdapter.TestCache.RedisCluster, as: Cache
  alias NebulexRedisAdapter.TestCache.{RedisClusterConnError, RedisClusterWithHashSlot}

  setup do
    {:ok, pid} = Cache.start_link()
    Cache.flush()

    on_exit(fn ->
      _ = :timer.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)
  end

  test "connection error" do
    assert {:error, %Redix.ConnectionError{reason: :closed}} = RedisClusterConnError.start_link()
  end

  test "hash tags on keys" do
    for i <- 0..10 do
      assert RedisCluster.hash_slot(Cache, "{foo}.#{i}") ==
               RedisCluster.hash_slot(Cache, "{foo}.#{i + 1}")

      assert RedisCluster.hash_slot(Cache, "{bar}.#{i}") ==
               RedisCluster.hash_slot(Cache, "{bar}.#{i + 1}")
    end

    assert RedisCluster.hash_slot(Cache, "{foo.1") != RedisCluster.hash_slot(Cache, "{foo.2")
  end

  test "set and get with hash tags" do
    assert :ok == Cache.set_many(%{"{foo}.1" => "bar1", "{foo}.2" => "bar2"})
    assert %{"{foo}.1" => "bar1", "{foo}.2" => "bar2"} == Cache.get_many(["{foo}.1", "{foo}.2"])
  end

  test "moved error" do
    assert {:ok, pid} = RedisClusterWithHashSlot.start_link()
    assert Process.alive?(pid)

    assert_raise Redix.Error, fn ->
      "bar" == RedisClusterWithHashSlot.set("1234567890", "hello")
    end

    refute Process.alive?(pid)
  end
end
