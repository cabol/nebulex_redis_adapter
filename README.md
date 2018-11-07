# Nebulex adapter for Redis

This adapter is implemented by means of [Redix](https://github.com/whatyouhide/redix),
a Redis driver for Elixir.

This adapter supports multiple connection pools against different Redis nodes
in a cluster. This feature enables resiliency, be able to survive in case any
node(s) gets unreachable.

## Installation

Add `nebulex_redis_adapter` to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:nebulex, "~> 1.0"},
    {:nebulex_redis_adapter, github: "cabol/nebulex_redis_adapter", branch: "master"}
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

## Usage

After installing, we can define our cache to use Redis adapter as follows:

```elixir
defmodule MyApp.RedisCache do
  use Nebulex.Cache,
    otp_app: :nebulex,
    adapter: NebulexRedisAdapter
end
```

The rest of Redis configuration is set in our application environment, usually
defined in your `config/config.exs`:

```elixir
config :my_app, MyApp.RedisCache,
  pools: [
    primary: [
      host: "127.0.0.1",
      port: 6379,
      pool_size: 10
    ],
    #=> maybe more pools
  ]
```

Since this adapter is implemented by means of `Redix`, it inherits the same
options, including regular Redis options and connection options as well. For
more information about the options, please check out `NebulexRedisAdapter`
module and also [Redix](https://github.com/whatyouhide/redix).

## Testing

Before to run the tests, ensure you have Redis up and running on **localhiost**
and port **6379**. Then run:

```
$ mix test
```

## Benchmarks

Benchmarks were added using [benchee](https://github.com/PragTob/benchee);
to learn more, see the [benchmarks](./benchmarks) directory.

To run the benchmarks:

```
$ mix run benchmarks/benchmark.exs
```

## Copyright and License

Copyright (c) 2018, Carlos Bolaños.

NebulexRedisAdapter source code is licensed under the [MIT License](LICENSE).
