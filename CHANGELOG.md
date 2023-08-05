# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.3.1](https://github.com/cabol/nebulex_redis_adapter/tree/v2.3.1) (2023-08-05)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v2.3.0...v2.3.1)

**Merged pull requests:**

- Fix parsing Redis Cluster info returned when running `CLUSTER SHARDS`.
  [#53](https://github.com/cabol/nebulex_redis_adapter/pull/53)
  ([norbajunior](https://github.com/norbajunior))

## [v2.3.0](https://github.com/cabol/nebulex_redis_adapter/tree/v2.3.0) (2023-05-20)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v2.2.0...v2.3.0)

**Implemented enhancements:**

- Allow passing Redis client options to `command` and `pipeline` functions
  [#51](https://github.com/cabol/nebulex_redis_adapter/issues/51)
- New Redis Cluster management strategy
  [#49](https://github.com/cabol/nebulex_redis_adapter/issues/49)
- Improve configuration for Redis Cluster mode
  [#47](https://github.com/cabol/nebulex_redis_adapter/issues/47)

**Closed issues:**

- Refactoring `Codec` to `Serializer`
  [#48](https://github.com/cabol/nebulex_redis_adapter/issues/48)
- Configurable codec to encode/decode Redis keys and values
  [#45](https://github.com/cabol/nebulex_redis_adapter/issues/45)
- Configuring `match_fun` in `conn_opts` fails to build release
  [#43](https://github.com/cabol/nebulex_redis_adapter/issues/43)
- Redis 7 issue
  [#38](https://github.com/cabol/nebulex_redis_adapter/issues/38)
- Allow deletion of multiple keys
  [#37](https://github.com/cabol/nebulex_redis_adapter/issues/37)

**Merged pull requests:**

- Log Cluster Connections Error
  [#52](https://github.com/cabol/nebulex_redis_adapter/pull/52)
  ([mjquinlan2000](https://github.com/mjquinlan2000))
- [#49] New Redis Cluster management strategy
  [#50](https://github.com/cabol/nebulex_redis_adapter/pull/50)
  ([cabol](https://github.com/cabol))
- [#45] Configurable codec to encode/decode Redis keys and values
  [#46](https://github.com/cabol/nebulex_redis_adapter/pull/46)
  ([cabol](https://github.com/cabol))
- Fix `:otp_app` option in README.md
  [#40](https://github.com/cabol/nebulex_redis_adapter/pull/40)
  ([nallwhy](https://github.com/nallwhy))

## [v2.2.0](https://github.com/cabol/nebulex_redis_adapter/tree/v2.2.0) (2022-03-13)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v2.1.2...v2.2.0)

**Implemented enhancements:**

- Add `command/3` and `pipeline/3` extended functions
  [#35](https://github.com/cabol/nebulex_redis_adapter/issues/35)
- Implement a Registry-based routing pool strategy
  [#34](https://github.com/cabol/nebulex_redis_adapter/issues/34)

## [v2.1.2](https://github.com/cabol/nebulex_redis_adapter/tree/v2.1.2) (2021-12-05)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v2.1.1...v2.1.2)

**Fixed bugs:**

- Raise an error when pipeline results contains one or more Redis errors
  [#33](https://github.com/cabol/nebulex_redis_adapter/issues/33)

**Closed issues:**

- Add Support for SSL
  [#32](https://github.com/cabol/nebulex_redis_adapter/issues/32)

**Merged pull requests:**

- Allow telemetry 1.0
  [#31](https://github.com/cabol/nebulex_redis_adapter/pull/31)
  ([bjyoungblood](https://github.com/bjyoungblood))

## [v2.1.1](https://github.com/cabol/nebulex_redis_adapter/tree/v2.1.1) (2021-05-24)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v2.1.0...v2.1.1)

**Implemented enhancements:**

- Add bootstrap server to run init and cleanup jobs (e.g.: attach/detach stats handler)
  [#30](https://github.com/cabol/nebulex_redis_adapter/issues/30)

**Closed issues:**

- NebulexRedisAdapter does not implement `c:stats/0`
  [#28](https://github.com/cabol/nebulex_redis_adapter/issues/28)

**Merged pull requests:**

- Add support for stats via `Nebulex.Telemetry.StatsHandler`
  [#29](https://github.com/cabol/nebulex_redis_adapter/pull/29)
  ([simoncocking](https://github.com/simoncocking))

## [v2.1.0](https://github.com/cabol/nebulex_redis_adapter/tree/v2.1.0) (2021-05-15)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v2.0.0...v2.1.0)

**Added features:**

- Instrument the adapter with Telemetry events
  [#27](https://github.com/cabol/nebulex_redis_adapter/issues/27)

**Merged pull requests:**

- Fix Small Typo on `NebulexRedisAdapter.fix_ttl/1`
  [#26](https://github.com/cabol/nebulex_redis_adapter/pull/26)
  ([lucas-cegatti](https://github.com/lucas-cegatti))

## [v2.0.0](https://github.com/cabol/nebulex_redis_adapter/tree/v2.0.0) (2021-02-20)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v2.0.0-rc.1...v2.0.0)

**Added features:**

- Added support for Nebulex v2.0.0

**Closed issues:**

- Nebulex v2.0.0 support
  [#25](https://github.com/cabol/nebulex_redis_adapter/issues/25)

## [v2.0.0-rc.1](https://github.com/cabol/nebulex_redis_adapter/tree/v2.0.0-rc.1) (2020-11-29)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v1.1.1...v2.0.0-rc.1)

**Implemented enhancements:**

- Allow storing raw strings, not the whole `Nebulex.Object.t()`
  [#15](https://github.com/cabol/nebulex_redis_adapter/issues/15)

**Closed issues:**

- Compatiblity with nebulex v2.0.0-rc.0?
  [#21](https://github.com/cabol/nebulex_redis_adapter/issues/21)
- Update redix dependency version to ~> 0.11
  [#19](https://github.com/cabol/nebulex_redis_adapter/issues/19)
- change redis address is invalid
  [#14](https://github.com/cabol/nebulex_redis_adapter/issues/14)

**Merged pull requests:**

- Overall fixes and enhancements
  [#24](https://github.com/cabol/nebulex_redis_adapter/pull/24)
  ([cabol](https://github.com/cabol))
- Migrate to Nebulex v2
  [#23](https://github.com/cabol/nebulex_redis_adapter/pull/23)
  ([cabol](https://github.com/cabol))
- Fix a small typo in readme
  [#22](https://github.com/cabol/nebulex_redis_adapter/pull/22)
  ([manusajith](https://github.com/manusajith))
- #19 redix ~> 0.11
  [#20](https://github.com/cabol/nebulex_redis_adapter/pull/20)
  ([diogommartins](https://github.com/diogommartins))

## [v1.1.1](https://github.com/cabol/nebulex_redis_adapter/tree/v1.1.1) (2020-01-25)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v1.1.0...v1.1.1)

**Closed issues:**

- jchash.start undefined function
  [#13](https://github.com/cabol/nebulex_redis_adapter/issues/13)
- Can you release?
  [#12](https://github.com/cabol/nebulex_redis_adapter/issues/12)

**Merged pull requests:**

- Compression of data in Redis
  [#18](https://github.com/cabol/nebulex_redis_adapter/pull/18)
  ([vovayartsev](https://github.com/vovayartsev))
- Replaced the redis FLUSHALL command by FLUSHDB
  [#17](https://github.com/cabol/nebulex_redis_adapter/pull/17)
  ([Atlas42](https://github.com/Atlas42))
- [#15] Allow storing raw strings, not the whole `Nebulex.Object.t()`
  [#16](https://github.com/cabol/nebulex_redis_adapter/pull/16)
  ([cabol](https://github.com/cabol))

## [v1.1.0](https://github.com/cabol/nebulex_redis_adapter/tree/v1.1.0) (2019-05-11)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/v1.0.0...v1.1.0)

**Implemented enhancements:**

- Default cluster support
  [#10](https://github.com/cabol/nebulex_redis_adapter/issues/10)

**Closed issues:**

- Redis Clustering on Redis 4+ without Sentinel
  [#8](https://github.com/cabol/nebulex_redis_adapter/issues/8)

**Merged pull requests:**

- Cluster Support
  [#11](https://github.com/cabol/nebulex_redis_adapter/pull/11)
  ([cabol](https://github.com/cabol))

## [v1.0.0](https://github.com/cabol/nebulex_redis_adapter/tree/v1.0.0) (2018-12-12)

[Full Changelog](https://github.com/cabol/nebulex_redis_adapter/compare/21160dbff1d8a6df333dc5c35fef46964649470b...v1.0.0)

**Implemented enhancements:**

- Add TravisCI support
  [#7](https://github.com/cabol/nebulex_redis_adapter/issues/7)
- Implement `Nebulex.Adapter.Transaction` interface
  [#2](https://github.com/cabol/nebulex_redis_adapter/issues/2)
- Implement `Nebulex.Adapter.Queryable` behaviour
  [#1](https://github.com/cabol/nebulex_redis_adapter/issues/1)



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
