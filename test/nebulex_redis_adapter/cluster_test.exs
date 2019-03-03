defmodule NebulexRedisAdapterTest.ClusterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest, cache: NebulexRedisAdapter.TestCache.Clustered

  alias NebulexRedisAdapter.TestCache.Clustered, as: Cache
  alias NebulexRedisAdapter.TestCache.ClusteredConnError

  setup do
    {:ok, local} = Cache.start_link()
    Cache.flush()

    on_exit(fn ->
      _ = :timer.sleep(100)
      if Process.alive?(local), do: Cache.stop(local)
    end)
  end

  test "connection error" do
    assert {:error, {%Redix.ConnectionError{reason: :closed}, _}} =
             ClusteredConnError.start_link()
  end

  test "hash tags on keys" do
    for i <- 0..10 do
      assert Cache.keyslot("{foo}.#{i}") == Cache.keyslot("{foo}.#{i + 1}")
      assert Cache.keyslot("{bar}.#{i}") == Cache.keyslot("{bar}.#{i + 1}")
    end
  end

  test "set and get with hash tags" do
    assert :ok == Cache.set_many(%{"{foo}.1" => "bar1", "{foo}.2" => "bar2"})
    assert %{"{foo}.1" => "bar1", "{foo}.2" => "bar2"} == Cache.get_many(["{foo}.1", "{foo}.2"])
  end
end
