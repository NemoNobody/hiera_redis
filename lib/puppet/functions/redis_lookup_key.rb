Puppet::Functions.create_function(:redis_lookup_key) do
  begin
    require 'redis'
  rescue LoadError
    raise Puppet::DataBinding::LookupError, 'The redis gem must be installed to use redis_lookup_key'
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
    socket    = options['socket']    || nil
    password  = options['password']  || nil
    db        = options['db']        || 0
    scopes    = options['scopes']    || [options['scope']]
    separator = options['separator'] || ':'

    redis = if !socket.nil? && !password.nil?
              Redis.new(path: socket, password: password, db: db)
            elsif !socket.nil? && password.nil?
              Redis.new(path: socket, db: db)
            elsif socket.nil? && !password.nil?
              Redis.new(password: password, host: host, port: port, db: db)
            else
              Redis.new(host: host, port: port, db: db)
            end
    result = nil

    scopes.each do |scope|
      redis_key = scope.nil? ? key : [scope, key].join(separator)
      result = redis_get(redis, redis_key)
      break unless result.nil?
    end

    context.not_found if result.nil?
    context.cache(key, result)
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
