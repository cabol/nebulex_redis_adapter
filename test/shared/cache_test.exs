defmodule NebulexRedisAdapter.CacheTest do
  @moduledoc """
  Shared Tests
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @cache Keyword.fetch!(opts, :cache)

      use Nebulex.Cache.ObjectTest, cache: @cache
      use Nebulex.Cache.TransactionTest, cache: @cache

      test "all" do
        set1 = for x <- 1..50, do: @cache.set(x, x)
        set2 = for x <- 51..100, do: @cache.set(x, x)

        for x <- 1..100, do: assert(@cache.get(x) == x)
        expected = set1 ++ set2

        assert expected == to_int(@cache.all())

        set3 = for x <- 20..60, do: @cache.delete(x, return: :key)
        expected = :lists.usort(expected -- set3)

        assert expected == to_int(@cache.all())
      end

      test "stream" do
        entries = for x <- 1..10, do: {x, x * 2}
        assert :ok == @cache.set_many(entries)

        expected = Keyword.keys(entries)
        stream = @cache.stream()
        assert expected == stream |> Enum.to_list() |> to_int()

        assert Keyword.values(entries) ==
                 entries
                 |> Keyword.keys()
                 |> @cache.get_many()
                 |> Map.values()

        stream = @cache.stream()
        [1 | _] = stream |> Enum.to_list() |> to_int()

        assert_raise Nebulex.QueryError, fn ->
          :invalid_query
          |> @cache.stream()
          |> Enum.to_list()
        end
      end

      test "all and stream with key pattern" do
        @cache.set_many(%{
          "firstname" => "Albert",
          "lastname" => "Einstein",
          "age" => 76
        })

        assert ["firstname", "lastname"] == "**name**" |> @cache.all() |> :lists.sort()
        assert ["age"] == "a??" |> @cache.all()
        assert ["age", "firstname", "lastname"] == :lists.sort(@cache.all())

        stream = @cache.stream("**name**")
        assert ["firstname", "lastname"] == stream |> Enum.to_list() |> :lists.sort()

        stream = @cache.stream("a??")
        assert ["age"] == stream |> Enum.to_list()

        stream = @cache.stream()
        assert ["age", "firstname", "lastname"] == stream |> Enum.to_list() |> :lists.sort()

        assert %{"firstname" => "Albert", "lastname" => "Einstein"} ==
                 "**name**" |> @cache.all() |> @cache.get_many()
      end

      test "string data type" do
        assert "bar" == @cache.set("foo", "bar", dt: :string)
        assert "bar" == @cache.get("foo")

        assert 123 == @cache.set("int", 123, dt: :string)
        assert "123" == @cache.get("int")

        assert :atom == @cache.set("atom", :atom, dt: :string)
        assert "atom" == @cache.get("atom")

        assert :ok == @cache.set_many(%{"foo" => "bar", 1 => 1, :a => :a}, dt: :string)
        assert %{"foo" => "bar", 1 => "1", :a => "a"} == @cache.get_many(["foo", 1, :a])
      end

      ## Private Functions

      defp to_int(keys), do: :lists.usort(for(k <- keys, do: String.to_integer(k)))
    end
  end
end
