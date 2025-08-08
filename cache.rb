def cache
  return @cache if defined?(@cache)

  unless File.exist?('cache.json')
    puts "❌ Erreur: Fichier 'cache.json' de cache introuvable"
    puts ""
    puts "Créez un fichier cache.json avec la structure suivante:"
    puts JSON.pretty_generate(
      {
      }
    )
    exit 1
  end

  @cache = JSON.parse(File.read('cache.json'))
end

def cache_get(key)
  cache[key.to_s]
end

def cache_set(key, value)
  cache[key.to_s] = value
  
  File.write('cache.json', JSON.pretty_generate(cache))
end