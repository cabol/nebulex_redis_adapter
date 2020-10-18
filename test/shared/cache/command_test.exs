defmodule NebulexRedisAdapter.Cache.CommandTest do
  import Nebulex.CacheCase

  deftests "command/pipeline" do
    test "returns an error", %{cache: cache} do
      assert_raise Redix.Error, fn ->
        cache.command!(["INCRBY", "counter", "invalid"])
      end
    end

    test "appends a value to the list", %{cache: cache} do
      assert cache.command!("mylist", ["LPUSH", "mylist", "world"]) == 1
      assert cache.command!("mylist", ["LPUSH", "mylist", "hello"]) == 2
      assert cache.command!("mylist", ["LRANGE", "mylist", "0", "-1"]) == ["hello", "world"]
    end

    test "runs the piped commands", %{cache: cache} do
      assert cache.pipeline!("mylist", [
               ["LPUSH", "mylist", "world"],
               ["LPUSH", "mylist", "hello"],
               ["LRANGE", "mylist", "0", "-1"]
             ]) == [1, 2, ["hello", "world"]]
    end
  end
end
