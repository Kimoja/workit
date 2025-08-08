def log(message)
  puts message
end

def log_success(message)
  log("✅ #{message}")
end

def log_warning(message)
  log("⚠️ Attention: #{message}")
end

def log_error(message)
  play_error_sound
  log("❌ Erreur: #{message}")
end

def log_json(json)
  log JSON.pretty_generate(json)
end
