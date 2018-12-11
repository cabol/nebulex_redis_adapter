# Nebulex adapter for Redis

[![Build Status](https://travis-ci.org/cabol/nebulex_redis_adapter.svg?branch=master)](https://travis-ci.org/cabol/nebulex_redis_adapter)
[![Coverage Status](https://coveralls.io/repos/github/cabol/nebulex_redis_adapter/badge.svg?branch=master)](https://coveralls.io/github/cabol/nebulex_redis_adapter?branch=master)
[![Inline docs](http://inch-ci.org/github/cabol/nebulex_redis_adapter.svg)](http://inch-ci.org/github/cabol/nebulex_redis_adapter)
[![Hex Version](https://img.shields.io/hexpm/v/nebulex_redis_adapter.svg)](https://hex.pm/packages/nebulex_redis_adapter)
[![Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/nebulex_redis_adapter)

This adapter is implemented using [Redix](https://github.com/whatyouhide/redix),
a Redis driver for Elixir.

This adapter supports multiple connection pools against different Redis nodes
in a cluster. This feature enables resiliency and also be able to survive
in case any node(s) gets unreachable.

## Installation

Add `nebulex_redis_adapter` to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:nebulex, "~> 1.0"},
    {:nebulex_redis_adapter, github: "cabol/nebulex_redis_adapter"}
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

## Distributed Caching

There are different ways to support distributed caching using
`NebulexRedisAdapter`.

> The good news is Redis is distributed as well, it is a built-in feature since
  version 3.0 (or greater) via [Redis Cluster](https://redis.io/topics/cluster-tutorial).

### Using Redis Cluster

By setting up [Redis Cluster](https://redis.io/topics/cluster-tutorial), all
distributed features and distribution work is automatically provided by Redis
Cluster under-the-hood. From the adapter's side, there is not additional work
more than add to the config the nodes of the cluster you want to cannect to.

> This one could be the easiest and recommended way for distributed caching
  using Redis and `NebulexRedisAdapter`.

### Using `Nebulex.Adapters.Dist`

Another simple option is to use the `Nebulex.Adapters.Dist` and set as local
cache the `NebulexRedisAdapter`. The idea here is that each Elixir node running
the distributed cache (`Nebulex.Adapters.Dist`) will have as local backend or
cache a Redis instance (handled by `NebulexRedisAdapter`).


This example shows how the setup a distributed cache using
`Nebulex.Adapters.Dist` and `NebulexRedisAdapter`:

```elixir
defmodule MyApp.DistributedCache do
  use Nebulex.Cache,
    otp_app: :nebulex,
    adapter: Nebulex.Adapters.Dist,
    local: MyApp.DistributedCache.RedisLocalCache

  defmodule RedisLocalCache do
    use Nebulex.Cache,
      otp_app: :nebulex,
      adapter: NebulexRedisAdapter
  end
end
```

### Using a Redis Proxy

The other option is to use a proxy, like [twemproxy](https://github.com/twitter/twemproxy)
on top of Redis. In this case, the proxy does the distribution work, and from
the adparter's side (`NebulexRedisAdapter`), it would be only configuration.
Instead of connect the adapter against the Redis nodes, we connect it against
the proxy nodes, this means, in the config, we just setup the pools with the
host and port for each proxy.

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
