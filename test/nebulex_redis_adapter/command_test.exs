defmodule NebulexRedisAdapter.CommandTest do
  use ExUnit.Case, async: true
  use Mimic

  alias NebulexRedisAdapter.Command

  describe "pipeline!/3" do
    test "error: raises an exception" do
      NebulexRedisAdapter.Pool
      |> expect(:get_conn, fn _, _, _ -> self() end)

      Redix
      |> expect(:pipeline, fn _, _, _ -> {:ok, [%Redix.Error{}]} end)

      assert_raise Redix.Error, fn ->
        Command.pipeline!(
          %{mode: :standalone, name: :test, registry: :test, pool_size: 1},
          [["PING"]]
        )
      end
    end
  end
end
