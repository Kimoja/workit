def config
  return @config if defined?(@config)

  unless File.exist?('config.json')
    log_error "Configuration file 'config.json' not found"
    log ""
    log "Create a config.json file with the following structure:"
    log_json(
      {
        "jira" => {
          "url" => "https://your-instance.atlassian.net",
          "email" => "your.email@example.com",
          "token" => "YOUR_API_TOKEN",
          "default_board" => "BOARD_NAME",
          "assignee_name" => "Your Name",
          "issue_type" => "Task"
        },
        "github": {
          "token": "XXX"
        }
      }
    )
    exit 1
  end

  @config = json_to_ostruct(JSON.parse(File.read('config.json')))
end

def json_to_ostruct(obj)
  case obj
  when Hash
    OpenStruct.new(obj.transform_values { |v| json_to_ostruct(v) })
  when Array
    obj.map { |item| json_to_ostruct(item) }
  else
    obj
  end
end