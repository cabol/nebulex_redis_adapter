defmodule NebulexRedisAdapter.TestCache do
  use Nebulex.Cache,
    otp_app: :nebulex_redis_adapter,
    adapter: NebulexRedisAdapter
end
