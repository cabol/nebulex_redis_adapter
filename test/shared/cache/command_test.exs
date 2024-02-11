defmodule NebulexRedisAdapter.Cache.CommandTest do
  import Nebulex.CacheCase

  deftests "Redis" do
    alias Nebulex.Adapter

    test "command/3 executes a command", %{cache: cache, name: name} do
      mode = Adapter.with_meta(name, fn _, %{mode: mode} -> mode end)

      if mode != :redis_cluster do
        assert cache.command(["SET", "foo", "bar"], timeout: 5000) == {:ok, "OK"}
        assert cache.command(["GET", "foo"]) == {:ok, "bar"}
      end
    end

    test "command/3 returns an error", %{cache: cache} do
      assert {:error, %Redix.Error{}} = cache.command(["INCRBY", "counter", "invalid"])
    end

    test "command!/3 raises an error", %{cache: cache} do
      assert_raise Redix.Error, fn ->
        cache.command!(["INCRBY", "counter", "invalid"])
      end
    end

    test "command!/3 with LIST", %{cache: cache} do
      assert cache.command!(["LPUSH", "mylist", "world"], key: "mylist") == 1
      assert cache.command!(["LPUSH", "mylist", "hello"], key: "mylist") == 2
      assert cache.command!(["LRANGE", "mylist", "0", "-1"], key: "mylist") == ["hello", "world"]
    end

    test "pipeline/3 runs the piped commands", %{cache: cache, name: name} do
      mode = Adapter.with_meta(name, fn _, %{mode: mode} -> mode end)

      if mode != :redis_cluster do
        assert cache.pipeline(
                 [
                   ["LPUSH", "mylist", "world"],
                   ["LPUSH", "mylist", "hello"],
                   ["LRANGE", "mylist", "0", "-1"]
                 ],
                 key: "mylist",
                 timeout: 5000
               ) == {:ok, [1, 2, ["hello", "world"]]}
      end
    end

    test "pipeline/3 returns an error", %{cache: cache} do
      assert {:ok, [%Redix.Error{}]} = cache.pipeline([["INCRBY", "counter", "invalid"]])
    end

    test "pipeline!/3 runs the piped commands", %{cache: cache} do
      assert cache.pipeline!(
               [
                 ["LPUSH", "mylist", "world"],
                 ["LPUSH", "mylist", "hello"],
                 ["LRANGE", "mylist", "0", "-1"]
               ],
               key: "mylist"
             ) == [1, 2, ["hello", "world"]]
    end

    test "pipeline!/3 returns an error", %{cache: cache} do
      assert_raise Redix.Error, fn ->
        cache.command!([["INCRBY", "counter", "invalid"]])
      end
    end
  end
end
