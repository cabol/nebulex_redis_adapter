defmodule NebulexRedisAdapter.RedisClusterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest

  alias NebulexRedisAdapter.RedisCluster
  alias NebulexRedisAdapter.TestCache.RedisCluster, as: Cache
  alias NebulexRedisAdapter.TestCache.{RedisClusterConnError, RedisClusterWithKeyslot}

  setup do
    {:ok, pid} = Cache.start_link()
    Cache.flush()

    on_exit(fn ->
      :ok = Process.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)

    {:ok, cache: Cache, name: Cache}
  end

  test "connection error" do
    assert {:error, %Redix.ConnectionError{reason: :closed}} = RedisClusterConnError.start_link()
  end

  test "hash tags on keys" do
    for i <- 0..10 do
      assert RedisCluster.hash_slot("{foo}.#{i}") ==
               RedisCluster.hash_slot("{foo}.#{i + 1}")

      assert RedisCluster.hash_slot("{bar}.#{i}") ==
               RedisCluster.hash_slot("{bar}.#{i + 1}")
    end

    assert RedisCluster.hash_slot("{foo.1") != RedisCluster.hash_slot("{foo.2")
  end

  test "set and get with hash tags" do
    assert :ok == Cache.put_all(%{"{foo}.1" => "bar1", "{foo}.2" => "bar2"})
    assert %{"{foo}.1" => "bar1", "{foo}.2" => "bar2"} == Cache.get_all(["{foo}.1", "{foo}.2"])
  end

  test "moved error" do
    assert {:ok, pid} = RedisClusterWithKeyslot.start_link()
    assert Process.alive?(pid)

    assert_raise Redix.Error, fn ->
      RedisClusterWithKeyslot.put("1234567890", "hello") == :ok
    end

    refute Process.alive?(pid)
  end
end
