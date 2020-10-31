defmodule NebulexRedisAdapter.TestCache do
  @moduledoc false

  defmodule Standalone do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule Cluster do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule RedisCluster do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule RedisClusterConnError do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule RedisClusterWithKeyslot do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  defmodule Keyslot do
    @moduledoc false
    use Nebulex.Adapter.Keyslot

    @impl true
    def hash_slot(key, range \\ 16_384) do
      key
      |> :erlang.phash2()
      |> :jchash.compute(range)
    end
  end
end
