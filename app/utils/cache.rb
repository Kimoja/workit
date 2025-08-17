module Utils
  module Cache
    extend self

    def cache
      return @cache if defined?(@cache)

      cache_path = "#{APP_PATH}/tmp/cache.json"

      unless File.exist?(cache_path)
        File.write(cache_path, '{}')

        Log.log "📁 Cache file created: #{cache_path}"
      end

      @cache = JSON.parse(File.read(cache_path))
    end

    def get(*keys, default: nil)
      return default
      return default if expired_key_cleaned?(*keys)

      result = cache.dig(*keys)
      result.nil? ? default : result
    end

    def set(*keys, value:, ttl: 7)
      last_key = keys.pop
      parent = keys.empty? ? cache : keys.reduce(cache) { |h, k| h[k] ||= {} }
      parent[last_key] = value
      parent["_#{last_key}_expire"] = Time.now + (ttl * 24 * 3600)

      value
    end

    def reset(*keys)
      last_key = keys.pop
      parent = keys.empty? ? cache : keys.reduce(cache) { |h, k| h[k] ||= {} }
      parent[last_key] = {}
      parent.delete("_#{last_key}_expire")
    end

    def save
      File.write("#{APP_PATH}/tmp/cache.json", JSON.pretty_generate(cache))
    end

    private

    def expired_key_cleaned?(*keys)
      parent_keys = keys.dup
      last_key = parent_keys.pop
      expire_key = "_#{last_key}_expire"

      if parent_keys.empty?
        parent = cache
        expire_time = cache[expire_key]
      else
        parent = cache.dig(*parent_keys)
        expire_time = parent&.dig(expire_key)
      end

      return false unless expire_time
      return false if Time.now.to_i < DateTime.parse(expire_time).to_time.to_i

      parent.delete(expire_key)
      parent.delete(last_key)

      true
    end
  end
end
