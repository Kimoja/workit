
def cache
  return @cache if defined?(@cache)

  cache_file_path = 'tmp/cache.json'
  
  unless File.exist?(cache_file_path)
    # Create empty cache file
    File.write(cache_file_path, '{}')
    
    log "📁 Cache file created: #{cache_file_path}"
  end

  @cache = JSON.parse(File.read(cache_file_path))
end

def cache_get(key)
  cache[key.to_s]
end

def cache_set(key, value)
  cache[key.to_s] = value
  
  File.write('tmp/cache.json', JSON.pretty_generate(cache))
end