
module Cache
  extend self

  def store
    return @store if defined?(@store)
  
    store_path = "#{APP_PATH}/tmp/cache.json"
    
    unless File.exist?(store_path)
      File.write(store_path, '{}')
      
      log "📁 Cache file created: #{store_path}"
    end
  
    @store = JSON.parse(File.read(store_path))
  end

  def get(key)
    store[key.to_s]
  end
  
  def set(key, value)
    store[key.to_s] = value
    
    File.write("#{APP_PATH}/tmp/cache.json", JSON.pretty_generate(cache))
  
    value
  end
end

def cache
  return @cache if defined?(@cache)

  cache_path = "#{APP_PATH}/tmp/cache.json"
  
  unless File.exist?(cache_path)
    File.write(cache_path, '{}')
    
    log "📁 Cache file created: #{cache_path}"
  end

  @cache = JSON.parse(File.read(cache_path))
end

def cache_get(key)
  cache[key.to_s]
end

def cache_set(key, value)
  cache[key.to_s] = value
  
  File.write("#{APP_PATH}/tmp/cache.json", JSON.pretty_generate(cache))

  value
end