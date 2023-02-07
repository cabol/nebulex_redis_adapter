defmodule NebulexRedisAdapter.Codec.StringProtoTest do
  use ExUnit.Case, async: true

  alias NebulexRedisAdapter.Codec.StringProto

  describe "encode/2" do
    test "error: raises Protocol.UndefinedError exception" do
      assert_raise Protocol.UndefinedError, ~r"cannot encode a bitstring to a string", fn ->
        StringProto.encode(<<1::1>>)
      end
    end
  end
end
