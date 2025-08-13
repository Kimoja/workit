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
      result = cache.dig(*keys)
      result.nil? ? default : result
    end

    def set(*keys, value:)
      last_key = keys.pop
      parent = keys.empty? ? cache : keys.reduce(cache) { |h, k| h[k] ||= {} }
      parent[last_key] = value

      value
    end

    def save
      File.write("#{APP_PATH}/tmp/cache.json", JSON.pretty_generate(cache))
    end
  end
end
