defmodule NebulexRedisAdapter.RedisClusterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest

  alias NebulexRedisAdapter.RedisCluster
  alias NebulexRedisAdapter.TestCache.RedisCluster, as: Cache
  alias NebulexRedisAdapter.TestCache.{RedisClusterConnError, RedisClusterWithKeyslot}

  setup do
    {:ok, pid} = Cache.start_link()
    _ = Cache.delete_all()

    on_exit(fn ->
      :ok = Process.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)

    {:ok, cache: Cache, name: Cache}
  end

  describe "connection" do
    test "error: connection is closed" do
      assert {:error, %Redix.ConnectionError{reason: :closed}} =
               RedisClusterConnError.start_link()
    end
  end

  describe "CRC16" do
    test "ok: returns the expected hash_slot" do
      assert RedisCluster.hash_slot("123456789") == {:"$hash_slot", 12_739}
    end
  end

  describe "keys hash tags" do
    test "hash_slot/2" do
      for i <- 0..10 do
        assert RedisCluster.hash_slot("{foo}.#{i}") ==
                 RedisCluster.hash_slot("{foo}.#{i + 1}")

        assert RedisCluster.hash_slot("{bar}.#{i}") ==
                 RedisCluster.hash_slot("{bar}.#{i + 1}")
      end

      assert RedisCluster.hash_slot("{foo.1") != RedisCluster.hash_slot("{foo.2")
    end

    test "with put and get operations" do
      assert :ok == Cache.put_all(%{"{foo}.1" => "bar1", "{foo}.2" => "bar2"})
      assert %{"{foo}.1" => "bar1", "{foo}.2" => "bar2"} == Cache.get_all(["{foo}.1", "{foo}.2"])
    end
  end

  describe "MOVED error" do
    test "when executing a Redis command/pipeline" do
      _ = Process.flag(:trap_exit, true)

      {:ok, _pid} = RedisClusterWithKeyslot.start_link()

      # put is executed throughout a Redis command
      assert_raise Redix.Error, ~r"MOVED", fn ->
        RedisClusterWithKeyslot.put("1234567890", "hello")
      end

      # get is executed throughout a Redis pipeline
      assert_raise Redix.Error, ~r"MOVED", fn ->
        RedisClusterWithKeyslot.get("1234567890", "hello")
      end
    end
  end
end
