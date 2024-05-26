defmodule NebulexRedisAdapter.Serializer.SerializableTest do
  use ExUnit.Case, async: true

  alias NebulexRedisAdapter.Serializer.Serializable

  defmodule Cache do
    use Nebulex.Cache,
      otp_app: :nebulex_redis_adapter,
      adapter: NebulexRedisAdapter
  end

  describe "encode/2" do
    test "error: raises Protocol.UndefinedError exception" do
      assert_raise Protocol.UndefinedError, ~r"cannot encode a bitstring to a string", fn ->
        Serializable.encode(<<1::1>>)
      end
    end
  end

  describe "encode/decode" do
    setup do
      {:ok, pid} = Cache.start_link()

      on_exit(fn ->
        :ok = Process.sleep(100)

        if Process.alive?(pid), do: Cache.stop(pid)
      end)

      {:ok, cache: Cache, name: Cache}
    end

    test "anonymous function is stored and then returned (not evaluated)" do
      fun = fn _x, _y ->
        _ = send(self(), "Hi!")

        {:cont, []}
      end

      assert Cache.put("fun", fun) == :ok
      assert value = Cache.get("fun")
      assert is_function(value, 2)
      assert value == fun
      assert Enum.to_list(value) == []
      assert_receive "Hi!"
    end
  end
end
