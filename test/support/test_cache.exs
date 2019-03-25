defmodule NebulexRedisAdapter.TestCache do
  defmodule Standalone do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule Cluster do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule RedisCluster do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule RedisClusterConnError do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule RedisClusterWithCustomHashSlot do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule HashSlot do
    @behaviour Nebulex.Adapter.HashSlot

    @impl true
    def keyslot(key, range \\ 16_384) do
      :erlang.phash2(key, range)
    end
  end
end
