
def cache
  return @cache if defined?(@cache)

  cache_path = "#{$cli_path}/tmp/cache.json"
  
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
  
  File.write("#{$cli_path}/tmp/cache.json", JSON.pretty_generate(cache))

  value
end