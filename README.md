# NebulexRedisAdapter
> Nebulex adapter for Redis (including [Redis Cluster][redis_cluster] support).

![CI](https://github.com/cabol/nebulex_redis_adapter/workflows/CI/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/cabol/nebulex_redis_adapter/badge.svg?branch=master)](https://coveralls.io/github/cabol/nebulex_redis_adapter?branch=master)
[![Hex Version](https://img.shields.io/hexpm/v/nebulex_redis_adapter.svg)](https://hex.pm/packages/nebulex_redis_adapter)
[![Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/nebulex_redis_adapter)

This adapter uses [Redix](https://github.com/whatyouhide/redix); a Redis driver
for Elixir.

The adapter supports different configurations modes which are explained in the
next sections.

See also [online documentation][nbx_redis_adapter]
and [Redis cache example][nbx_redis_example].

[nbx_redis_adapter]: http://hexdocs.pm/nebulex_redis_adapter/NebulexRedisAdapter.html
[nbx_redis_example]: https://github.com/cabol/nebulex_examples/tree/master/redis_cache
[redis_cluster]: https://redis.io/topics/cluster-tutorial

## Installation

Add `:nebulex_redis_adapter` to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:nebulex_redis_adapter, "~> 2.3"},
    {:crc, "~> 0.10"},    #=> Needed when using Redis Cluster
    {:jchash, "~> 0.1.4"} #=> Needed when using consistent-hashing
  ]
end
```

The adapter dependencies are optional to give more flexibility and loading only
needed ones. For example:

  * `:crc` - Required when using the adapter in mode `:redis_cluster`.
    See [Redis Cluster][redis_cluster].
  * `:jchash` - Required if you want to use consistent-hashing when using the
    adapter in mode `:client_side_cluster`.

Then run `mix deps.get` to fetch the dependencies.

## Usage

After installing, we can define our cache to use Redis adapter as follows:

```elixir
defmodule MyApp.RedisCache do
  use Nebulex.Cache,
    otp_app: :my_app,
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

See also [Redis cache example][nbx_redis_example].

## Distributed Caching

There are different ways to support distributed caching when using
**NebulexRedisAdapter**.

### Redis Cluster

[Redis Cluster][redis_cluster] is a built-in feature in Redis since version 3,
and it may be the most convenient and recommendable way to set up Redis in a
cluster and have a distributed cache storage out-of-box. This adapter provides
the `:redis_cluster` mode to set up **Redis Cluster** from the client-side
automatically and be able to use it transparently.

First of all, ensure you have **Redis Cluster** configured and running.

Then we can define our cache which will use **Redis Cluster**:

```elixir
defmodule MyApp.RedisClusterCache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: NebulexRedisAdapter
end
```

The config:

```elixir
config :my_app, MyApp.RedisClusterCache,
  # Enable redis_cluster mode
  mode: :redis_cluster,

  # For :redis_cluster mode this option must be provided
  redis_cluster: [
    # Configuration endpoints
    # This is where the client will connect and send the "CLUSTER SHARDS"
    # (Redis >= 7) or "CLUSTER SLOTS" (Redis < 7) command to get the cluster
    # information and set it up on the client side.
    configuration_endpoints: [
      endpoint1_conn_opts: [
        host: "127.0.0.1",
        port: 6379,
        # Add the password if 'requirepass' is on
        password: "password"
      ]
    ]
  ]
```

The pool of connections to the different master nodes is automatically
configured by the adapter once it gets the cluster slots info.

> This one could be the easiest and recommended way for distributed caching
  using Redis and **NebulexRedisAdapter**.

### Client-side Cluster based on Sharding

**NebulexRedisAdapter** also brings with a simple client-side cluster
implementation based on Sharding distribution model.

We define our cache normally:

```elixir
defmodule MyApp.ClusteredCache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: NebulexRedisAdapter
end
```

The config:

```elixir
config :my_app, MyApp.ClusteredCache,
  # Enable client-side cluster mode
  mode: :client_side_cluster,

  # For :client_side_cluster mode this option must be provided
  client_side_cluster: [
    # Nodes config (each node has its own options)
    nodes: [
      node1: [
        # Node pool size
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
  ]
```

By default, the adapter uses `NebulexRedisAdapter.ClientCluster.Keyslot` for the
keyslot. Besides, if `:jchash` is defined as dependency, the adapter will use
consistent-hashing automatically.

> **NOTE:** It is highly recommended to define the `:jchash` dependency
  when using the adapter in `:client_side_cluster` mode.

However, you can also provide your own implementation by implementing the
`Nebulex.Adapter.Keyslot` and set it into the `:keyslot` option. For example:

```elixir
defmodule MyApp.ClusteredCache.Keyslot do
  use Nebulex.Adapter.Keyslot

  @impl true
  def hash_slot(key, range) do
    # your implementation goes here
  end
end
```

And the config:

```elixir
config :my_app, MyApp.ClusteredCache,
  # Enable client-side cluster mode
  mode: :client_side_cluster,

  client_side_cluster: [
    # Provided Keyslot implementation
    keyslot: MyApp.ClusteredCache.Keyslot,

    # Nodes config (each node has its own options)
    nodes: [
      ...
    ]
  ]
```

### Using `Nebulex.Adapters.Partitioned`

Another simple option is to use the `Nebulex.Adapters.Partitioned` and set as
local cache the `NebulexRedisAdapter`. The idea here is each Elixir node running
the distributed cache (`Nebulex.Adapters.Partitioned`) will have as local
backend or cache a Redis instance (handled by `NebulexRedisAdapter`).


This example shows how the setup a distributed cache using
`Nebulex.Adapters.Partitioned` and `NebulexRedisAdapter`:

```elixir
defmodule MyApp.DistributedCache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: Nebulex.Adapters.Partitioned,
    primary_storage_adapter: NebulexRedisAdapter
end
```

### Using a Redis Proxy

The other option is to use a proxy, like [Envoy proxy][envoy] or
[Twemproxy][twemproxy] on top of Redis. In this case, the proxy does the
distribution work, and from the adparter's side (**NebulexRedisAdapter**),
it would be only configuration. Instead of connect the adapter against the
Redis nodes, we connect it against the proxy nodes, this means, in the config,
we setup the pool with the host and port pointing to the proxy.

[envoy]: https://www.envoyproxy.io/
[twemproxy]: https://github.com/twitter/twemproxy

## Running Redis commands and/or pipelines

Since `NebulexRedisAdapter` works on top of `Redix` and provides features like
connection pools and "Redis Cluster" support, it may be seen also as a sort of
Redis client, but it is meant to be used mainly with the Nebulex cache API.
However, Redis API is quite extensive and there are a lot of useful commands
we may want to run taking advantage of the `NebulexRedisAdapter` features.
Therefore, the adapter injects two additional/extended functions to the
defined cache: `command!/2` and `pipeline!/2`.

```elixir
iex> MyCache.command!(["LPUSH", "mylist", "world"], key: "mylist")
1
iex> MyCache.command!(["LPUSH", "mylist", "hello"], key: "mylist")
2
iex> MyCache.command!(["LRANGE", "mylist", "0", "-1"], key: "mylist")
["hello", "world"]

iex> [
...>   ["LPUSH", "mylist", "world"],
...>   ["LPUSH", "mylist", "hello"],
...>   ["LRANGE", "mylist", "0", "-1"]
...> ]
...> |> cache.pipeline!(key: "mylist")
[1, 2, ["hello", "world"]]
```

**NOTE:** The `key` is required when used the adapter in mode
`:client_side_cluster` or `:redis_cluster`. For `:standalone` is not required
(optional). And the `name` is in case you are using a dynamic cache and
you have to pass the cache name explicitly.

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

Since `NebulexRedisAdapter` uses the support modules and shared tests
from `Nebulex` and by default its test folder is not included in the Hex
dependency, the following steps are required for running the tests.

First of all, make sure you set the environment variable `NEBULEX_PATH`
to `nebulex`:

```
export NEBULEX_PATH=nebulex
```

Second, make sure you fetch `:nebulex` dependency directly from GtiHub
by running:

```
mix nbx.setup
```

Third, fetch deps:

```
mix deps.get
```

Finally, you can run the tests:

```
mix test
```

Running tests with coverage:

```
mix coveralls.html
```

You will find the coverage report within `cover/excoveralls.html`.

## Benchmarks

Benchmarks were added using [benchee](https://github.com/PragTob/benchee);
to learn more, see the [benchmarks](./benchmarks) directory.

To run the benchmarks:

```
$ MIX_ENV=test mix run benchmarks/benchmark.exs
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

Before to submit a PR it is highly recommended to run `mix check` and ensure
all checks run successfully.

## Copyright and License

Copyright (c) 2018, Carlos Bolaños.

NebulexRedisAdapter source code is licensed under the [MIT License](LICENSE).
