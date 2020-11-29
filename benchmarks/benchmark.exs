## Benchmarks

defmodule BenchCache do
  use Nebulex.Cache,
      otp_app: :nebulex,
      adapter: NebulexRedisAdapter
end

# start caches
{:ok, local} = BenchCache.start_link()

# samples
keys = Enum.to_list(1..10_000)
bulk = for x <- 1..100, do: {x, x}

# init caches
Enum.each(1..5000, &BenchCache.put(&1, &1))

inputs = %{
  "Redis Cache" => BenchCache
}

benchmarks = %{
  "get" => fn {cache, random} ->
    cache.get(random)
  end,
  "get_all" => fn {cache, _random} ->
    cache.get_all([1, 2, 3, 4, 5, 6, 7, 8, 9])
  end,
  "put" => fn {cache, random} ->
    cache.put(random, random)
  end,
  "put_new" => fn {cache, random} ->
    cache.put_new(random, random)
  end,
  "replace" => fn {cache, random} ->
    cache.replace(random, random)
  end,
  "put_all" => fn {cache, _random} ->
    cache.put_all(bulk)
  end,
  "delete" => fn {cache, random} ->
    cache.delete(random)
  end,
  "take" => fn {cache, random} ->
    cache.take(random)
  end,
  "has_key?" => fn {cache, random} ->
    cache.has_key?(random)
  end,
  "size" => fn {cache, _random} ->
    cache.size()
  end,
  "ttl" => fn {cache, random} ->
    cache.ttl(random)
  end,
  "expire" => fn {cache, random} ->
    cache.expire(random, 1000)
  end,
  "incr" => fn {cache, _random} ->
    cache.incr(:counter, 1)
  end,
  "update" => fn {cache, random} ->
    cache.update(random, 1, &Kernel.+(&1, 1))
  end,
  "get_and_update" => fn {cache, random} ->
    cache.get_and_update(random, fn
      nil -> {nil, 1}
      val -> {val, val * 2}
    end)
  end,
  "all" => fn {cache, _random} ->
    cache.all()
  end
}

Benchee.run(
  benchmarks,
  inputs: inputs,
  before_scenario: fn cache ->
    {cache, Enum.random(keys)}
  end,
  formatters: [
    {Benchee.Formatters.Console, comparison: false, extended_statistics: true},
    {Benchee.Formatters.HTML, extended_statistics: true, auto_open: false}
  ],
  print: [
    fast_warning: false
  ]
)

# stop caches s
if Process.alive?(local), do: Supervisor.stop(local)
