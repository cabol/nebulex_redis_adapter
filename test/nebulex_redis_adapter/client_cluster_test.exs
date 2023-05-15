defmodule NebulexRedisAdapter.ClientClusterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest

  alias NebulexRedisAdapter.TestCache.ClientCluster, as: Cache

  setup do
    {:ok, pid} = Cache.start_link()
    _ = Cache.delete_all()
    :ok

    on_exit(fn ->
      :ok = Process.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)

    {:ok, cache: Cache, name: Cache}
  end

  describe "cluster setup" do
    test "error: missing :client_side_cluster option" do
      defmodule ClientClusterWithInvalidOpts do
        @moduledoc false
        use Nebulex.Cache,
          otp_app: :nebulex_redis_adapter,
          adapter: NebulexRedisAdapter
      end

      _ = Process.flag(:trap_exit, true)

      assert {:error, {%ArgumentError{message: msg}, _}} =
               ClientClusterWithInvalidOpts.start_link(mode: :client_side_cluster)

      assert Regex.match?(~r/invalid value for :client_side_cluster option: expected/, msg)
    end
  end
end
