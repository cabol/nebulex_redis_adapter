defmodule NebulexRedisAdapterTest do
  use ExUnit.Case, async: true
  use NebulexRedisAdapter.CacheTest, cache: NebulexRedisAdapter.TestCache

  alias NebulexRedisAdapter.TestCache

  setup do
    {:ok, local} = TestCache.start_link()
    TestCache.flush()
    :ok

    on_exit(fn ->
      _ = :timer.sleep(100)
      if Process.alive?(local), do: TestCache.stop(local)
    end)
  end

  test "fail on __before_compile__ because missing pool_size in config" do
    assert_raise ArgumentError, ~r"missing :pools configuration", fn ->
      defmodule WrongCache do
        use Nebulex.Cache,
          otp_app: :nebulex,
          adapter: NebulexRedisAdapter
      end
    end
  end

  test "all" do
    set1 = for x <- 1..50, do: TestCache.set(x, x)
    set2 = for x <- 51..100, do: TestCache.set(x, x)

    for x <- 1..100, do: assert(TestCache.get(x) == x)
    expected = set1 ++ set2

    assert expected == to_int(TestCache.all())

    set3 = for x <- 20..60, do: TestCache.delete(x, return: :key)
    expected = :lists.usort(expected -- set3)

    assert expected == to_int(TestCache.all())
  end

  test "stream" do
    entries = for x <- 1..10, do: {x, x * 2}
    assert :ok == TestCache.set_many(entries)

    expected = Keyword.keys(entries)
    stream = TestCache.stream()
    assert expected == stream |> Enum.to_list() |> to_int()

    assert Keyword.values(entries) ==
             entries
             |> Keyword.keys()
             |> TestCache.get_many()
             |> Map.values()

    stream = TestCache.stream()
    [1 | _] = stream |> Enum.to_list() |> to_int()

    assert_raise Nebulex.QueryError, fn ->
      :invalid_query
      |> TestCache.stream()
      |> Enum.to_list()
    end
  end

  test "all and stream with key pattern" do
    TestCache.set_many(%{
      "firstname" => "Albert",
      "lastname" => "Einstein",
      "age" => 76
    })

    assert ["firstname", "lastname"] == "**name**" |> TestCache.all() |> :lists.sort()
    assert ["age"] == "a??" |> TestCache.all()
    assert ["age", "firstname", "lastname"] == :lists.sort(TestCache.all())

    stream = TestCache.stream("**name**")
    assert ["firstname", "lastname"] == stream |> Enum.to_list() |> :lists.sort()

    stream = TestCache.stream("a??")
    assert ["age"] == stream |> Enum.to_list()

    stream = TestCache.stream()
    assert ["age", "firstname", "lastname"] == stream |> Enum.to_list() |> :lists.sort()

    assert %{"firstname" => "Albert", "lastname" => "Einstein"} ==
             "**name**" |> TestCache.all() |> TestCache.get_many()
  end

  ## Private Functions

  defp to_int(keys), do: :lists.usort(for(k <- keys, do: String.to_integer(k)))
end
