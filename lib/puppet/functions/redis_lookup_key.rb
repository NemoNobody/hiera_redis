Puppet::Functions.create_function(:redis_lookup_key) do
  begin
    require 'redis'
    require 'json'

  rescue LoadError
    raise Puppet::DataBinding::LookupError, 'The redis and json  gem must be installed to use redis_lookup_key'
  end

  dispatch :redis_lookup_key do
    param 'Variant[String, Numeric]', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def redis_lookup_key(key, options, context)
    return context.cached_value(key) if context.cache_has_key(key)

    if (confine_keys = options['confine_to_keys'])
      raise ArgumentError, '[hiera-redis] confine_to_keys must be an array' unless confine_keys.is_a?(Array)

      begin
        confine_keys = confine_keys.map { |r| Regexp.new(r) }
      rescue StandardError => e
        raise Puppet::DataBinding::LookupError, "[hiera-redis] creating regexp failed with: #{e}"
      end

      regex_key_match = Regexp.union(confine_keys)

      unless key[regex_key_match] == key
        context.explain { "[hiera-redis] Skipping hiera_redis backend because key '#{key}' does not match confine_to_keys" }
        context.not_found
      end
    end

    host      = options['host']      || 'localhost'
    port      = options['port']      || 6379
    sentinel  = options['sentinel']  || nil
    socket    = options['socket']    || nil
    password  = options['password']  || nil
    db        = options['db']        || 0
    scopes    = options['scopes']    || [options['scope']]
    separator = options['separator'] || ':'
# timeout options, by default 0.5 seconds
    connect_timeout = options['connect_timeout'] || 0.5
    read_timeout = options['read_timeout'] || 0.5
    write_timeout = options['write_timeout'] || 0.5
# added timeouts for redis connections
# without it, we will get a lot of not closed TCP connections
    @redis = @redis || {
      debug('hiera-redis: Setting up Redis connection')
      if !sentinel.nil?
        debug('hiera-redis: Using Redis sentinel')
        sentinels = sentinel['sentinels'].map { |val| val.transform_keys(&:to_sym) }
        begin
          tred = Redis.new(name: sentinel['name'], sentinels: sentinels, role: :replica, db: db, connect_timeout: connect_timeout, read_timeout: read_timeout, write_timeout: write_timeout)
          # this is necessary in order to trigger the potential connection error
          #   early enough to try other connection options
          tred.ping
          tred
        rescue Redis::BaseError => e
          if e.message.include? "Couldn't locate a replica"
            tred = Redis.new(name: sentinel['name'], sentinels: sentinels, role: :master, db: db, connect_timeout: connect_timeout, read_timeout: read_timeout, write_timeout: write_timeout)
          end
        end
      elsif !socket.nil? && !password.nil?
        debug('hiera-redis: Using socket with password')
        Redis.new(path: socket, password: password, db: db, connect_timeout: connect_timeout, read_timeout: read_timeout, write_timeout: write_timeout)
      elsif !socket.nil? && password.nil?
        debug('hiera-redis: Using socket without password')
        Redis.new(path: socket, db: db, connect_timeout: connect_timeout, read_timeout: read_timeout, write_timeout: write_timeout)
      elsif socket.nil? && !password.nil?
        debug('hiera-redis: Using TCP with password')
        Redis.new(password: password, host: host, port: port, db: db, connect_timeout: connect_timeout, read_timeout: read_timeout, write_timeout: write_timeout)
      else
        debug('hiera-redis: Using TCP without password')
        Redis.new(host: host, port: port, db: db, connect_timeout: connect_timeout, read_timeout: read_timeout, write_timeout: write_timeout)
      end
    }
    result = nil

    scopes.each do |scope|
      redis_key = scope.nil? ? key : [scope, key].join(separator)
      debug("hiera-redis: Looking up '#{redis_key}'")
      result = redis_get(@redis, redis_key)

      break unless result.nil?
    end
    # close redis connection, for fix issue with TCP connects
    # redis.close()

    context.not_found if result.nil?
    # if result contains some hiera or lookup pattern for interpolate it, we need try to make it
    #to interpolate some subincluded lookups neet interpolate result in first.
    if (result.include? "%{hiera") || (result.include? "%{lookup")
      result =  context.interpolate(result)
    end
    # if we can validate json in result, we need to make it and change type of result for context.
    if valid_json(result)
       context.cache(key, Hash(JSON.parse(result)))
    else
       context.cache(key, result)
    end
  end
# we just trt validate it, if we can without error - return true, if not - false.
  def valid_json(json)
      JSON.parse(json)
      return true
  rescue TypeError, JSON::ParserError => e
     return false
  end

  def redis_get(redis, key)
    case redis.type(key)
    when 'string'
      redis.get(key)
    when 'list'
      redis.lrange(key, 0, -1)
    when 'set'
      redis.smembers(key)
    when 'zset'
      redis.zrange(key, 0, -1)
    when 'hash'
      redis.hgetall(key)
    end
  end
end
