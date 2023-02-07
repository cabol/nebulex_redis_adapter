defmodule NebulexRedisAdapter.StatsTest do
  use ExUnit.Case, async: true

  defmodule Cache do
    use Nebulex.Cache,
      otp_app: :nebulex,
      adapter: NebulexRedisAdapter
  end

  setup do
    {:ok, pid} = Cache.start_link(stats: true, conn_opts: [database: 1])

    on_exit(fn ->
      :ok = Process.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)

    {:ok, cache: Cache, name: Cache}
  end

  describe "c:NebulexRedisAdapter.stats/1" do
    test "returns valid %Stats{}" do
      size = Cache.delete_all()

      refute Cache.get("stats")
      assert Cache.put("stats", "stats") == :ok
      assert Cache.get("stats") == "stats"
      assert Cache.put("stats", "stats") == :ok
      assert Cache.take("stats") == "stats"
      refute Cache.get("stats")
      assert Cache.put_new("stats", "stats")
      assert Cache.replace("stats", "stats stats")
      assert Cache.delete_all() == 1

      assert stats = Cache.stats()
      assert stats.measurements.evictions == size + 2
      assert stats.measurements.hits == 2
      assert stats.measurements.misses == 2
      assert stats.measurements.writes == 3
      assert stats.measurements.updates == 1
    end
  end
end
