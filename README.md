# hiera_redis

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with hiera_redis](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with hiera_redis](#beginning-with-hiera_redis)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)
6. [Credits - credits to developers](#credits)

## Description

This module provides a Hiera 5 backend for Redis.
With support recieve from redis hash instead String only. JSON requered for this module.
Also support interpolate results from redis - patterns in result like `%{hiera('somekey')}` or  `%{lookup('somekey')}`  will be replaced to `somekey` value from Hiera.

## Setup

### Setup Requirements

The backend requires the [redis](https://github.com/redis/redis-rb) gem installed in the Puppet Server JRuby.
It can be installed with:

    /opt/puppetlabs/bin/puppetserver gem install redis

It is also recommended to install the gem into the agent's Ruby:

    /opt/puppetlabs/puppet/bin/gem install redis

This allows commands such as `puppet apply` or `puppet lookup` to use the backend.

Also need to install `json` gem

### Beginning with hiera_redis

If Redis is running on the Puppet master with the default settings, specifying the `lookup_key` as 'redis_lookup_key' is sufficient, for example:

```yaml
---
version: 5
hierarchy:
  - name: hiera_redis
    lookup_key: redis_lookup_key
```

## Usage

By default, the backend will query Redis with the key provided.
It is also possible to query multiple scopes such as with the YAML backend, where the expected key in Redis is composed of the scope and the key separated by a character (default is `:`). For example, the following can be used:

```yaml
---
version: 5
hierarchy:
  - name: hiera_redis
    lookup_key: redis_lookup_key
    options:
      confine_to_keys:
        - '^redis_.*'
        - '^myapp_.*'
        - '^ssh_group$'
      scopes:
        - "osfamily/%{facts.os.family}"
        - common
```

The backend then expects keys of a format such as `common:foo::bar` for a lookup of 'foo::bar'.

The other options available include:

* `host`: The host that Redis is located on. Defaults to 'localhost'.
* `port`: The port that Redis is running on. Defaults to 6379.
* `sentinel`: Sentinel configuration (described below)
* `socket`: Optional Unix socket path
* `password`: Optional Redis password
* `db`: The database number to query on the Redis instance. Defaults to 0.
* `scope`: The scope to use when querying the database.
* `scopes`: An array of scopes to query. Cannot be used in conjunction with the `scope` option.
* `separator`: The character separator between the scope and key being queried. Defaults to ':'.
* `confine_to_keys`: Only use this backend if the key matches one of the regexes in the array.
* `connect_timeout`: connect timeout to redis, seconds. Default 0.5
* `read_timeout`: read timeout for redis, seconds. Default 0.5
* `write_timeout`: write timeout for redis, seconds. Default 0.5

### confine_to_keys config example:

```yaml
  confine_to_keys:
    - "application.*"
    - "apache::.*"
```

### Sentinel configuration

Include the `sentinel` key in `options` and then use the following config (from [Redis gem v5.0.7](https://www.rubydoc.info/gems/redis/5.0.7#sentinel-support))
`password` key is optional.

```yaml
---
version: 5
hierarchy:
  - name: hiera_redis
    lookup_key: redis_lookup_key
    options:
      sentinel:
        name: mymaster
        sentinels:
          - host: '127.0.0.1'
            port: 26380
            password: optional_password
          - host: '127.0.0.1'
            port: 26381
            password: optional_password
```

## Limitations

Tested partly for puppet5, use for you own risk.

## Credits

This repository was initially a fork from [maxadamo hiera_redis](https://github.com/maxadamo/hiera_redis) repo, forked for add some fix.

The code to related to add supporting of getting hashes also from hiera redis storage. For now if in recieved result from redis we have "{" and "}" symvols, we will change type of result as HASH and puppet will be use result from redis as hash.
