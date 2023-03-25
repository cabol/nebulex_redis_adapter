defmodule NebulexRedisAdapter.RedisClusterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest
  use Mimic

  import Nebulex.CacheCase, only: [with_telemetry_handler: 3]

  alias NebulexRedisAdapter.RedisCluster
  alias NebulexRedisAdapter.TestCache.RedisCluster, as: Cache
  alias NebulexRedisAdapter.TestCache.{RedisClusterConnError, RedisClusterWithKeyslot}

  setup do
    {:ok, pid} = Cache.start_link()
    _ = Cache.delete_all()

    on_exit(fn ->
      :ok = Process.sleep(100)

      if Process.alive?(pid), do: Cache.stop(pid)
    end)

    {:ok, cache: Cache, name: Cache}
  end

  describe "cluster setup" do
    setup do
      start_event = telemetry_event(:redis_cluster_conn_error, :start)
      stop_event = telemetry_event(:redis_cluster_conn_error, :stop)

      {:ok, events: [start_event, stop_event]}
    end

    test "error: connection with config endpoint cannot be established", %{events: [_, stop]} do
      with_telemetry_handler(__MODULE__, [stop], fn ->
        {:ok, _pid} = RedisClusterConnError.start_link()

        # 1st failed attempt
        assert_receive {^stop, %{duration: _}, %{status: :error}}, 5000

        # 2dn failed attempt
        assert_receive {^stop, %{duration: _}, %{status: :error}}, 5000
      end)
    end

    test "error: redis cluster status is set to error", %{events: [start, stop] = events} do
      with_telemetry_handler(__MODULE__, events, fn ->
        {:ok, _} =
          RedisClusterConnError.start_link(
            conn_opts: [
              host: "127.0.0.1",
              port: 7000
            ]
          )

        assert_receive {^start, _, %{pid: pid}}, 5000
        assert_receive {^stop, %{duration: _}, %{status: :ok}}, 5000

        :ok = GenServer.stop(pid)

        assert_raise NebulexRedisAdapter.Error, ~r"Redis Cluster is in error status", fn ->
          RedisClusterConnError.get("foo")
        end
      end)
    end

    test "error: command failed after reconfiguring cluster", %{events: [_, stop]} do
      with_telemetry_handler(__MODULE__, [stop], fn ->
        {:ok, _} =
          RedisClusterConnError.start_link(
            conn_opts: [
              host: "127.0.0.1",
              port: 7000
            ]
          )

        assert_receive {^stop, %{duration: _}, %{status: :ok}}, 5000

        # Setup mocks
        NebulexRedisAdapter.RedisCluster
        |> expect(:get_conn, fn _, _, _ -> nil end)

        refute RedisClusterConnError.get("foo")

        assert_receive {^stop, %{duration: _}, %{status: :ok}}, 5000
      end)
    end
  end

  describe "CRC16" do
    test "ok: returns the expected hash_slot" do
      assert RedisCluster.hash_slot("123456789") == {:"$hash_slot", 12_739}
    end
  end

  describe "keys hash tags" do
    test "hash_slot/2" do
      for i <- 0..10 do
        assert RedisCluster.hash_slot("{foo}.#{i}") ==
                 RedisCluster.hash_slot("{foo}.#{i + 1}")

        assert RedisCluster.hash_slot("{bar}.#{i}") ==
                 RedisCluster.hash_slot("{bar}.#{i + 1}")
      end

      assert RedisCluster.hash_slot("{foo.1") != RedisCluster.hash_slot("{foo.2")
    end

    test "with put and get operations" do
      assert Cache.put_all(%{"{foo}.1" => "bar1", "{foo}.2" => "bar2"}) == :ok

      assert Cache.get_all(["{foo}.1", "{foo}.2"]) == %{"{foo}.1" => "bar1", "{foo}.2" => "bar2"}
    end
  end

  describe "MOVED" do
    setup do
      stop_event = telemetry_event(:redis_cluster, :stop)

      {:ok, events: [stop_event]}
    end

    test "error: raises an exception in the 2nd attempt after reconfiguring the cluster" do
      _ = Process.flag(:trap_exit, true)

      {:ok, _pid} = RedisClusterWithKeyslot.start_link()

      # put is executed throughout a Redis command
      assert_raise Redix.Error, ~r"MOVED", fn ->
        RedisClusterWithKeyslot.put("1234567890", "hello")
      end

      # put_all is executed throughout a Redis pipeline
      assert_raise Redix.Error, ~r"MOVED", fn ->
        RedisClusterWithKeyslot.put_all(foo: "bar", bar: "foo")
      end
    end

    test "ok: command is successful after configuring the cluster", %{events: [stop] = events} do
      with_telemetry_handler(__MODULE__, events, fn ->
        # Setup mocks
        NebulexRedisAdapter.RedisCluster.Keyslot
        |> expect(:hash_slot, fn _, _ -> 0 end)

        # Triggers MOVED error the first time, then the command succeeds
        :ok = Cache.put("foo", "bar")

        # Cluster is re-configured
        assert_receive {^stop, %{duration: _}, %{status: :ok}}, 5000

        # Command was executed successfully
        assert Cache.get("foo") == "bar"
      end)
    end
  end

  ## Private functions

  defp telemetry_event(cache, event) do
    [
      :nebulex_redis_adapter,
      :test_cache,
      cache,
      :config_manager,
      :setup,
      event
    ]
  end
end
