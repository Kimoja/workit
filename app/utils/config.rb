module Utils
  module Config
    extend self

    def config
      return @config if defined?(@config)

      config_path = "#{APP_PATH}/config.json"

      unless File.exist?(config_path)
        Log.error "Configuration file '#{config_path}' not found"
        Log.log ''
        Log.log 'Create a config.json by copying the structure of config.example.json'
        raise
      end

      @config = JSON.parse(File.read(config_path))
    end

    def get(*keys, default: nil)
      resolved_keys = keys.map { |key| resolve_config_reference(key) }
      result = config.dig(*resolved_keys)
      result.nil? ? default : result
    end

    def resolve_config_reference(key, depth = 0)
      return key if depth > 5

      if key.to_s.start_with?('@')
        config_key = key.to_s[1..]
        resolved_value = config[config_key]

        raise "Config reference '@#{config_key}' not found" if resolved_value.nil?

        resolve_config_reference(resolved_value, depth + 1) if resolved_value.to_s.start_with?('@')

        resolved_value
      else
        key
      end
    end
  end
end
