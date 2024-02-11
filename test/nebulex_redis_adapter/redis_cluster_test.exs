defmodule NebulexRedisAdapter.RedisClusterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest
  use Mimic

  import Nebulex.CacheCase, only: [with_telemetry_handler: 3]

  alias NebulexRedisAdapter.RedisCluster
  alias NebulexRedisAdapter.TestCache.RedisCluster, as: Cache
  alias NebulexRedisAdapter.TestCache.RedisClusterConnError

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

    test "error: missing :redis_cluster option" do
      defmodule RedisClusterWithInvalidOpts do
        @moduledoc false
        use Nebulex.Cache,
          otp_app: :nebulex_redis_adapter,
          adapter: NebulexRedisAdapter
      end

      _ = Process.flag(:trap_exit, true)

      assert {:error, {%ArgumentError{message: msg}, _}} =
               RedisClusterWithInvalidOpts.start_link(mode: :redis_cluster)

      assert Regex.match?(~r/invalid value for :redis_cluster option: expected non-empty/, msg)
    end

    test "error: invalid :redis_cluster options" do
      _ = Process.flag(:trap_exit, true)

      assert {:error, {%ArgumentError{message: msg}, _}} =
               Cache.start_link(name: :redis_cluster_invalid_opts1, redis_cluster: [])

      assert Regex.match?(~r/invalid value for :redis_cluster option: expected non-empty/, msg)
    end

    test "error: invalid :keyslot option" do
      _ = Process.flag(:trap_exit, true)

      assert {:error, {%ArgumentError{message: msg}, _}} =
               Cache.start_link(
                 name: :redis_cluster_invalid_opts2,
                 redis_cluster: [configuration_endpoints: [x: []], keyslot: RedisClusterConnError]
               )

      assert msg ==
               "invalid value for :keyslot option: expected " <>
                 "NebulexRedisAdapter.TestCache.RedisClusterConnError " <>
                 "to implement the behaviour Nebulex.Adapter.Keyslot"
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
            redis_cluster: [
              configuration_endpoints: [
                endpoint1_conn_opts: [
                  host: "127.0.0.1",
                  port: 6380,
                  password: "password"
                ]
              ],
              override_master_host: true
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

    test "error: command failed after reconfiguring cluster", %{events: [start, stop] = events} do
      with_telemetry_handler(__MODULE__, events, fn ->
        {:ok, _} =
          RedisClusterConnError.start_link(
            redis_cluster: [
              configuration_endpoints: [
                endpoint1_conn_opts: [
                  url: "redis://127.0.0.1:6380",
                  password: "password"
                ]
              ],
              override_master_host: true
            ]
          )

        assert_receive {^start, _, %{pid: pid}}, 5000

        # Setup mocks - testing Redis version < 7 (["CLUSTER", "SLOTS"])
        Redix
        |> expect(:command, fn _, _ -> {:error, %Redix.Error{}} end)
        |> expect(:command, fn _, _ -> {:ok, [[0, 16_384, ["127.0.0.1", 6380]]]} end)
        |> allow(self(), pid)

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

  describe "keys with hash tags" do
    test "hash_slot/2" do
      for i <- 0..10 do
        assert RedisCluster.hash_slot("{foo}.#{i}") ==
                 RedisCluster.hash_slot("{foo}.#{i + 1}")

        assert RedisCluster.hash_slot("{bar}.#{i}") ==
                 RedisCluster.hash_slot("{bar}.#{i + 1}")
      end

      assert RedisCluster.hash_slot("{foo.1") != RedisCluster.hash_slot("{foo.2")
    end

    test "put and get operations" do
      assert Cache.put_all(%{"{foo}.1" => "bar1", "{foo}.2" => "bar2"}) == :ok

      assert Cache.get_all(["{foo}.1", "{foo}.2"]) == %{"{foo}.1" => "bar1", "{foo}.2" => "bar2"}
    end

    test "put and get operations with tupled keys" do
      assert Cache.put_all(%{
               {RedisCache.Testing, "key1"} => "bar1",
               {RedisCache.Testing, "key2"} => "bar2"
             }) == :ok

      assert Cache.get_all([{RedisCache.Testing, "key1"}, {RedisCache.Testing, "key2"}]) == %{
               {RedisCache.Testing, "key1"} => "bar1",
               {RedisCache.Testing, "key2"} => "bar2"
             }

      assert Cache.put_all(%{
               {RedisCache.Testing, {Nested, "key1"}} => "bar1",
               {RedisCache.Testing, {Nested, "key2"}} => "bar2"
             }) == :ok

      assert Cache.get_all([
               {RedisCache.Testing, {Nested, "key1"}},
               {RedisCache.Testing, {Nested, "key2"}}
             ]) == %{
               {RedisCache.Testing, {Nested, "key1"}} => "bar1",
               {RedisCache.Testing, {Nested, "key2"}} => "bar2"
             }
    end
  end

  describe "MOVED" do
    setup do
      stop_event = telemetry_event(:redis_cluster, :stop)

      {:ok, events: [stop_event]}
    end

    test "error: raises an exception in the 2nd attempt after reconfiguring the cluster" do
      _ = Process.flag(:trap_exit, true)

      # Setup mocks
      NebulexRedisAdapter.RedisCluster.Keyslot
      |> stub(:hash_slot, &:erlang.phash2/2)

      # put is executed with a Redis command
      assert_raise Redix.Error, ~r"MOVED", fn ->
        Cache.put("1234567890", "hello")
      end

      # put_all is executed with a Redis pipeline
      assert_raise Redix.Error, ~r"MOVED", fn ->
        Cache.put_all(foo: "bar", bar: "foo")
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
