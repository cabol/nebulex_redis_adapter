defmodule NebulexRedisAdapterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest, cache: NebulexRedisAdapter.TestCache.Standalone

  alias NebulexRedisAdapter.Command
  alias NebulexRedisAdapter.TestCache.Standalone, as: Cache
  alias NebulexRedisAdapter.TestCache.StandaloneWithURL

  setup do
    {:ok, pid} = Cache.start_link()
    Cache.flush()
    :ok

    on_exit(fn ->
      _ = :timer.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)
  end

  test "fail on __before_compile__ because missing redix_opts in config" do
    assert_raise ArgumentError, ~r"missing :redix_opts configuration", fn ->
      defmodule WrongCache do
        use Nebulex.Cache,
          otp_app: :nebulex,
          adapter: NebulexRedisAdapter
      end
    end
  end

  test "connection with URL" do
    {:ok, pid} = StandaloneWithURL.start_link()
    if Process.alive?(pid), do: StandaloneWithURL.stop(pid)
  end

  test "command error" do
    assert_raise Redix.Error, fn ->
      Command.exec!(Cache, ["INCRBY", "counter", "invalid"])
    end
  end
end
