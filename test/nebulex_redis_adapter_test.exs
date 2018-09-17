defmodule NebulexRedisAdapterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest, cache: NebulexRedisAdapter.TestCache

  alias NebulexRedisAdapter.TestCache

  setup do
    {:ok, local} = TestCache.start_link()
    TestCache.flush()
    :ok

    on_exit(fn ->
      _ = :timer.sleep(100)
      if Process.alive?(local), do: TestCache.stop(local)
    end)
  end

  test "fail on __before_compile__ because missing pool_size in config" do
    assert_raise ArgumentError, ~r"missing :pools configuration", fn ->
      defmodule WrongCache do
        use Nebulex.Cache,
          otp_app: :nebulex,
          adapter: NebulexRedisAdapter
      end
    end
  end
end
