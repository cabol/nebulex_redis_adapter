defmodule NebulexRedisAdapter.TestCache do
  defmodule Standalone do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule StandaloneWithURL do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule Clustered do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule ClusteredConnError do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule ClusteredWithCustomHashSlot do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule HashSlotGen do
    @behaviour NebulexRedisAdapter.Cluster.HashSlot

    @impl true
    def compute(key) do
      :erlang.phash(key, 16_384)
    end
  end
end
