## Benchmarks

Application.put_env(
  :nebulex,
  BenchCache,
  pools: [
    primary: [
      host: "127.0.0.1",
      port: 6379
    ]
  ]
)

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
Enum.each(1..5000, &BenchCache.set(&1, &1))

inputs = %{
  "Redis Cache" => BenchCache
}

benchmarks = %{
  "get" => fn {cache, random} ->
    cache.get(random)
  end,
  "set" => fn {cache, random} ->
    cache.set(random, random)
  end,
  "add" => fn {cache, random} ->
    cache.add(random, random)
  end,
  "replace" => fn {cache, random} ->
    cache.replace(random, random)
  end,
  "add_or_replace!" => fn {cache, random} ->
    cache.add_or_replace!(random, random)
  end,
  "get_many" => fn {cache, _random} ->
    cache.get_many([1, 2, 3, 4, 5, 6, 7, 8, 9])
  end,
  "set_many" => fn {cache, _random} ->
    cache.set_many(bulk)
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
  "object_info" => fn {cache, random} ->
    cache.object_info(random, :ttl)
  end,
  "expire" => fn {cache, random} ->
    cache.expire(random, 1)
  end,
  "get_and_update" => fn {cache, random} ->
    cache.get_and_update(random, fn
      nil -> {nil, 1}
      val -> {val, val * 2}
    end)
  end,
  "update" => fn {cache, random} ->
    cache.update(random, 1, &Kernel.+(&1, 1))
  end,
  "update_counter" => fn {cache, _random} ->
    cache.update_counter(:counter, 1)
  end,
  "all" => fn {cache, _random} ->
    cache.all()
  end,
  "transaction" => fn {cache, random} ->
    cache.transaction(
      fn ->
        cache.update(random, 1, &Kernel.+(&1, 1))
        :ok
      end,
      keys: [random]
    )
  end
}

Benchee.run(
  benchmarks,
  inputs: inputs,
  before_scenario: fn cache ->
    {cache, Enum.random(keys)}
  end,
  console: [
    comparison: false,
    extended_statistics: true
  ],
  formatters: [
    Benchee.Formatters.Console,
    Benchee.Formatters.HTML
  ],
  formatter_options: [
    html: [
      auto_open: false
    ]
  ],
  print: [
    fast_warning: false
  ]
)

# stop caches s
if Process.alive?(local), do: BenchCache.stop(local)
