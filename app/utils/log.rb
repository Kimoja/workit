module Utils
  module Log
    extend self

    def log(message)
      puts message
    end

    def info(message)
      Log.log("ℹ #{message}")
    end

    def success(message)
      Log.log("✅ #{message}")
    end

    def warn(message)
      Log.log("⚠️ Warning: #{message}")
    end

    def error(message)
      Play.error
      Log.log("❌ Erreur: #{message}")
    end

    def json(json)
      Log.log JSON.pretty_generate(json)
    end
  end
end
