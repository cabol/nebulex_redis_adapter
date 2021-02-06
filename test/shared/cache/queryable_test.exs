defmodule NebulexRedisAdapter.Cache.QueryableTest do
  import Nebulex.CacheCase

  deftests "queryable" do
    import Nebulex.CacheHelpers

    test "all/2", %{cache: cache} do
      set1 = cache_put(cache, 1..50)
      set2 = cache_put(cache, 51..100)

      for x <- 1..100, do: assert(cache.get(x) == x)
      expected = set1 ++ set2

      assert :lists.usort(cache.all()) == expected

      set3 = Enum.to_list(20..60)
      :ok = Enum.each(set3, &cache.delete(&1))
      expected = :lists.usort(expected -- set3)

      assert :lists.usort(cache.all()) == expected
    end

    test "stream/2", %{cache: cache} do
      entries = for x <- 1..10, into: %{}, do: {x, x * 2}
      assert cache.put_all(entries) == :ok

      expected = Map.keys(entries)
      assert nil |> cache.stream() |> Enum.to_list() |> :lists.usort() == expected

      assert nil
             |> cache.stream(page_size: 3)
             |> Enum.to_list()
             |> :lists.usort() == expected

      assert_raise Nebulex.QueryError, fn ->
        :invalid_query
        |> cache.stream()
        |> Enum.to_list()
      end
    end

    test "all/2 and stream/2 with key pattern", %{cache: cache} do
      cache.put_all(%{
        "firstname" => "Albert",
        "lastname" => "Einstein",
        "age" => 76
      })

      assert ["firstname", "lastname"] == "**name**" |> cache.all() |> :lists.sort()
      assert ["age"] == "a??" |> cache.all()
      assert ["age", "firstname", "lastname"] == :lists.sort(cache.all())

      stream = cache.stream("**name**")
      assert ["firstname", "lastname"] == stream |> Enum.to_list() |> :lists.sort()

      stream = cache.stream("a??")
      assert ["age"] == stream |> Enum.to_list()

      stream = cache.stream()
      assert ["age", "firstname", "lastname"] == stream |> Enum.to_list() |> :lists.sort()

      assert %{"firstname" => "Albert", "lastname" => "Einstein"} ==
               "**name**" |> cache.all() |> cache.get_all()
    end

    test "delete_all/2", %{cache: cache} do
      :ok = cache.put_all(a: 1, b: 2, c: 3)

      assert cache.count_all() == 3
      assert cache.delete_all() == 3
      assert cache.count_all() == 0
    end
  end
end
