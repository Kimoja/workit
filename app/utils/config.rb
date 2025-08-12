module Utils
  module Config
    extend self

    def config
      return @config if defined?(@config)

      config_path = "#{APP_PATH}/config.json"

      unless File.exist?(config_path)
        Log.error "Configuration file '#{config_path}' not found"
        Log.log ''
        Log.log 'Create a config.json file with the following structure:'
        Log.json(
          {
            'jira' => {
              'url' => 'https://your-instance.atlassian.net',
              'email' => 'your.email@example.com',
              'token' => 'YOUR_API_TOKEN',
              'default_board' => 'BOARD_NAME',
              'assignee_name' => 'Your Name',
              'issue_type' => 'Task'
            },
            github: {
              token: 'XXX'
            }
          }
        )
        raise
      end

      @config = JSON.parse(File.read(config_path))
    end

    def get(*keys, default: nil)
      result = config.dig(*keys)
      result.nil? ? default : result
    end
  end
end
