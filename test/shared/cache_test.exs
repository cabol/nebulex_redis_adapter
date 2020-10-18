defmodule NebulexRedisAdapter.CacheTest do
  @moduledoc """
  Shared Tests
  """

  defmacro __using__(_opts) do
    quote do
      use Nebulex.Cache.EntryTest
      use NebulexRedisAdapter.Cache.EntryExpTest
      use NebulexRedisAdapter.Cache.QueryableTest
      use NebulexRedisAdapter.Cache.CommandTest
    end
  end
end
