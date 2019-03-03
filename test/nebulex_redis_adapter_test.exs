defmodule NebulexRedisAdapterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest, cache: NebulexRedisAdapter.TestCache.Standalone

  alias NebulexRedisAdapter.TestCache.Standalone, as: Cache
  alias NebulexRedisAdapter.TestCache.StandaloneWithURL

  setup do
    {:ok, local} = Cache.start_link()
    Cache.flush()
    :ok

    on_exit(fn ->
      _ = :timer.sleep(100)
      if Process.alive?(local), do: Cache.stop(local)
    end)
  end

  test "fail on __before_compile__ because missing redix_opts in config" do
    assert_raise ArgumentError, ~r"missing :redix_opts configuration", fn ->
      defmodule WrongCache do
        use Nebulex.Cache,
          otp_app: :nebulex,
          adapter: NebulexRedisAdapter
      end
    end
  end

  test "connection with URL" do
    {:ok, local} = StandaloneWithURL.start_link()
    if Process.alive?(local), do: StandaloneWithURL.stop(local)
  end

  test "all" do
    set1 = for x <- 1..50, do: Cache.set(x, x)
    set2 = for x <- 51..100, do: Cache.set(x, x)

    for x <- 1..100, do: assert(Cache.get(x) == x)
    expected = set1 ++ set2

    assert expected == to_int(Cache.all())

    set3 = for x <- 20..60, do: Cache.delete(x, return: :key)
    expected = :lists.usort(expected -- set3)

    assert expected == to_int(Cache.all())
  end

  test "stream" do
    entries = for x <- 1..10, do: {x, x * 2}
    assert :ok == Cache.set_many(entries)

    expected = Keyword.keys(entries)
    stream = Cache.stream()
    assert expected == stream |> Enum.to_list() |> to_int()

    assert Keyword.values(entries) ==
             entries
             |> Keyword.keys()
             |> Cache.get_many()
             |> Map.values()

    stream = Cache.stream()
    [1 | _] = stream |> Enum.to_list() |> to_int()

    assert_raise Nebulex.QueryError, fn ->
      :invalid_query
      |> Cache.stream()
      |> Enum.to_list()
    end
  end

  test "all and stream with key pattern" do
    Cache.set_many(%{
      "firstname" => "Albert",
      "lastname" => "Einstein",
      "age" => 76
    })

    assert ["firstname", "lastname"] == "**name**" |> Cache.all() |> :lists.sort()
    assert ["age"] == "a??" |> Cache.all()
    assert ["age", "firstname", "lastname"] == :lists.sort(Cache.all())

    stream = Cache.stream("**name**")
    assert ["firstname", "lastname"] == stream |> Enum.to_list() |> :lists.sort()

    stream = Cache.stream("a??")
    assert ["age"] == stream |> Enum.to_list()

    stream = Cache.stream()
    assert ["age", "firstname", "lastname"] == stream |> Enum.to_list() |> :lists.sort()

    assert %{"firstname" => "Albert", "lastname" => "Einstein"} ==
             "**name**" |> Cache.all() |> Cache.get_many()
  end

  ## Private Functions

  defp to_int(keys), do: :lists.usort(for(k <- keys, do: String.to_integer(k)))
end
