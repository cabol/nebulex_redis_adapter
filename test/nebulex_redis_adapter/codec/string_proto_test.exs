defmodule NebulexRedisAdapter.Serializer.SerializableTest do
  use ExUnit.Case, async: true

  alias NebulexRedisAdapter.Serializer.Serializable

  describe "encode/2" do
    test "error: raises Protocol.UndefinedError exception" do
      assert_raise Protocol.UndefinedError, ~r"cannot encode a bitstring to a string", fn ->
        Serializable.encode(<<1::1>>)
      end
    end
  end
end
