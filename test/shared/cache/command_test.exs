defmodule NebulexRedisAdapter.Cache.CommandTest do
  import Nebulex.CacheCase

  deftests "Redis" do
    test "command/3 executes a command", %{cache: cache} do
      assert cache.command(["SET", "foo", "bar"]) == {:ok, "OK"}
      assert cache.command(["GET", "foo"]) == {:ok, "bar"}
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
      assert cache.command!("mylist", ["LPUSH", "mylist", "world"]) == 1
      assert cache.command!("mylist", ["LPUSH", "mylist", "hello"]) == 2
      assert cache.command!("mylist", ["LRANGE", "mylist", "0", "-1"]) == ["hello", "world"]
    end

    test "pipeline/3 runs the piped commands", %{cache: cache} do
      assert cache.pipeline("mylist", [
               ["LPUSH", "mylist", "world"],
               ["LPUSH", "mylist", "hello"],
               ["LRANGE", "mylist", "0", "-1"]
             ]) == {:ok, [1, 2, ["hello", "world"]]}
    end

    test "pipeline/3 returns an error", %{cache: cache} do
      assert {:ok, [%Redix.Error{}]} = cache.pipeline([["INCRBY", "counter", "invalid"]])
    end

    test "pipeline!/3 runs the piped commands", %{cache: cache} do
      assert cache.pipeline!("mylist", [
               ["LPUSH", "mylist", "world"],
               ["LPUSH", "mylist", "hello"],
               ["LRANGE", "mylist", "0", "-1"]
             ]) == [1, 2, ["hello", "world"]]
    end

    test "pipeline!/3 returns an error", %{cache: cache} do
      assert_raise Redix.Error, fn ->
        cache.command!([["INCRBY", "counter", "invalid"]])
      end
    end
  end
end
