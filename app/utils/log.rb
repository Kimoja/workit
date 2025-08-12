module Utils
  module Log
    extend self

    def log(message)
      puts message
    end

    def pad(message)
      Log.log("  #{message}")
    end

    def info(message)
      Log.log("ℹ #{message}")
    end

    def start(message)
      Log.log("\e[34m▶ #{message}\e[0m")
    end

    def success(message)
      Log.log("\e[32m✓ #{message}\e[0m")
    end

    def warn(message)
      Log.log("\e[33m⚠ Warning: #{message}\e[0m")
    end

    def error(message)
      Play.error
      Log.log("\e[31m✗ Erreur: #{message}\e[0m")
    end

    def json(json)
      Log.log JSON.pretty_generate(json)
    end
  end
end