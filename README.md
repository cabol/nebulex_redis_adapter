# NebulexRedisAdapter
> ### Nebulex adapter for Redis with cluster support.

[![Build Status](https://travis-ci.org/cabol/nebulex_redis_adapter.svg?branch=master)](https://travis-ci.org/cabol/nebulex_redis_adapter)
[![Coverage Status](https://coveralls.io/repos/github/cabol/nebulex_redis_adapter/badge.svg?branch=master)](https://coveralls.io/github/cabol/nebulex_redis_adapter?branch=master)
[![Inline docs](http://inch-ci.org/github/cabol/nebulex_redis_adapter.svg)](http://inch-ci.org/github/cabol/nebulex_redis_adapter)
[![Hex Version](https://img.shields.io/hexpm/v/nebulex_redis_adapter.svg)](https://hex.pm/packages/nebulex_redis_adapter)
[![Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/nebulex_redis_adapter)

This adapter is implemented using [Redix](https://github.com/whatyouhide/redix),
a Redis driver for Elixir.

The adapter supports different configurations modes which are explained in the
next sections.

You can also check the [online documentation][nebulex_redis_adapter] to learn
more about it.

[nebulex_redis_adapter]: http://hexdocs.pm/nebulex_redis_adapter/NebulexRedisAdapter.html

## Installation

Add `nebulex_redis_adapter` to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:nebulex_redis_adapter, "~> 1.1"}
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
  conn_opts: [
    # Redix options
    host: "127.0.0.1",
    port: 6379
  ]
```

Since this adapter is implemented by means of `Redix`, it inherits the same
options, including regular Redis options and connection options as well. For
more information about the options, please check out `NebulexRedisAdapter`
module and also [Redix](https://github.com/whatyouhide/redix).

## Distributed Caching

There are different ways to support distributed caching when using
**NebulexRedisAdapter**.

> To learn more about the available config options for the different cluster
  alternatives below, check out the [online documentation][nebulex_redis_adapter].

### Redis Cluster

Redis can be setup in distributed fashion by means of [Redis Cluster][redis_cluster],
which is a built-in feature since version 3.0 (or greater). The adapter provides
the `:redis_cluster` mode to setup **Redis Cluster** from client-side
automatically and be able to use it transparently.

[redis_cluster]: https://redis.io/topics/cluster-tutorial

First of all, ensure you have **Redis Cluster** configured and running.

Then we can define our cache which will use **Redis Cluster**:

```elixir
defmodule MyApp.RedisClusterCache do
  use Nebulex.Cache,
    otp_app: :nebulex,
    adapter: NebulexRedisAdapter
end
```

The config:

```elixir
config :my_app, MayApp.RedisClusterCache,
  # Enable redis_cluster mode
  mode: :redis_cluster,

  # Master nodes. There must be at least one, in order the adapter be able to
  # get the cluster slots and configure the client side automatically.
  # If one fails, the adapter retries with the next in the list.
  master_nodes: [
    [
      host: "127.0.0.1",
      port: 7000
    ],
    [
      url: "redis://127.0.0.1:7001"
    ],
    # Maybe more master nodes ...
  ],

  # Redix options, except `:host` and `:port`; unless we have a cluster
  # of nodes with the same host and/or port, which doesn't make sense.
  conn_opts: [
    # Maybe Redix options
  ]
```

The pool of connections against the different master nodes is automatically
configured by the adapter once it gets the cluster slots info.

> This one could be the easiest and recommended way for distributed caching
  using Redis and **NebulexRedisAdapter**.

### Client-side Cluster based on Sharding (and consistent hashing)

**NebulexRedisAdapter** also brings with a simple client-side cluster
implementation based on Sharding as distribution model and consistent
hashing for node resolution.

We define our cache normally:

```elixir
defmodule MyApp.ClusteredCache do
  use Nebulex.Cache,
    otp_app: :nebulex,
    adapter: NebulexRedisAdapter
end
```

And then, within the config:

```elixir
config :my_app, MayApp.ClusteredCache,
  # Enable client-side cluster mode
  mode: :cluster,

  # Nodes config (each node has its own options)
  nodes: [
    node1: [
      # Node poll size
      pool_size: 10,

      # Redix options to establish the pool of connections against this node
      conn_opts: [
        host: "127.0.0.1",
        port: 9001
      ]
    ],
    node2: [
      pool_size: 4,
      conn_opts: [
        url: "redis://127.0.0.1:9002"
      ]
    ],
    node3: [
      conn_opts: [
        host: "127.0.0.1",
        port: 9003
      ]
    ]
    # Maybe more ...
  ]
```

That's all, the rest of the work is done by **NebulexRedisAdapter**
automatically.

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
the adparter's side (**NebulexRedisAdapter**), it would be only configuration.
Instead of connect the adapter against the Redis nodes, we connect it against
the proxy nodes, this means, in the config, we just setup the pools with the
host and port for each proxy.

## Testing

To run the **NebulexRedisAdapter** tests you will have to have Redis running
locally. **NebulexRedisAdapter** requires a complex setup for running tests
(since it needs a few instances running, for standalone, cluster and Redis
Cluster). For this reason, there is a [docker-compose.yml](docker-compose.yml)
file in the repo so that you can use [Docker][docker] and
[docker-compose][docker_compose] to spin up all the necessary Redis instances
with just one command. Make sure you have Docker installed and then just run:

```
$ docker-compose up
```

[docker]: https://www.docker.com/
[docker_compose]: https://docs.docker.com/compose/

Since **NebulexRedisAdapter** uses the support modules and shared tests from
**Nebulex** and by default its `test` folder is not included within the `hex`
dependency, it is necessary to fetch `:nebulex` dependency directly from GtiHub.
This is done by setting the environment variable `NBX_TEST`, like so:

```
$ export NBX_TEST=true
```

Fetch deps:

```
$ mix deps.get
```

Now we can run the tests:

```
$ mix test
```

Running tests with coverage:

```
$ mix coveralls.html
```

You can find the coverage report within `cover/excoveralls.html`.

## Benchmarks

Benchmarks were added using [benchee](https://github.com/PragTob/benchee);
to learn more, see the [benchmarks](./benchmarks) directory.

To run the benchmarks:

```
$ mix deps.get && mix run benchmarks/benchmark.exs
```

> Benchmarks use default Redis options (`host: "127.0.0.1", port: 6379`).

## Contributing

Contributions to Nebulex are very welcome and appreciated!

Use the [issue tracker](https://github.com/cabol/nebulex_redis_adapter/issues)
for bug reports or feature requests. Open a
[pull request](https://github.com/cabol/nebulex_redis_adapter/pulls)
when you are ready to contribute.

When submitting a pull request you should not update the [CHANGELOG.md](CHANGELOG.md),
and also make sure you test your changes thoroughly, include unit tests
alongside new or changed code.

Before to submit a PR it is highly recommended to run:

 * `export NBX_TEST=true` to fetch Nebulex from GH directly and be able to
   re-use shared tests.
 * `mix test` to run tests
 * `mix coveralls.html && open cover/excoveralls.html` to run tests and check
   out code coverage (expected 100%).
 * `mix format && mix credo --strict` to format your code properly and find code
   style issues
 * `mix dialyzer` to run dialyzer for type checking; might take a while on the
   first invocation

## Copyright and License

Copyright (c) 2018, Carlos Bolaños.

NebulexRedisAdapter source code is licensed under the [MIT License](LICENSE).
