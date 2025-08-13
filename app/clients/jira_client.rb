module Clients
  class JiraClient < Client
    def self.build_from_config!
      url = Config.get('jira', 'url')
      email = Config.get('jira', 'email')
      token = Config.get('jira', 'token')

      raise "Configuration parameter 'jira.url' is required" if url.nil? || token.strip.empty?

      unless url.match?(%r{\Ahttps?://.+\.atlassian\.net\z})
        Log.warn "Warning: Jira URL doesn't appear to be a standard Atlassian URL"
        Log.log "Configured URL: #{url}"
      end

      raise "Configuration parameter 'jira.email' is required" if email.nil? || email.strip.empty?

      raise "Configuration parameter 'jira.token' is required" if token.nil? || token.strip.empty?

      new(base_url: url, token: Base64.strict_encode64("#{email}:#{token}"))
    end

    def fetch_issue(key)
      map_issue(get("/rest/api/2/issue/#{key}"))
    end

    def create_issue(payload)
      map_issue(post('/rest/api/2/issue', payload))
    end

    def fetch_boards
      get('/rest/agile/1.0/board')['values']
    end

    def fetch_board(board_id)
      get("/rest/agile/1.0/board/#{board_id}")
    end

    def fetch_board_configuration(board_id)
      get("/rest/agile/1.0/board/#{board_id}/configuration")
    end

    def fetch_active_sprint(board_id)
      get("/rest/agile/1.0/board/#{board_id}/sprint?state=active")['values'].first
    end

    def fetch_fields
      get('/rest/api/2/field')
    end

    def fetch_field_by_name(name)
      fetch_fields.find { |f| f['name'] == name }
    end

    def fetch_issue_types(project_key)
      project = get(
        "/rest/api/2/issue/createmeta?projectKeys=#{project_key}&expand=projects.issuetypes"
      )['projects'].first

      return unless project

      project['issuetypes'].map { |type| type['name'] }
    end

    def fetch_user_by_name(name)
      encoded_name = URI.encode_www_form_component(name)
      response = get("/rest/api/3/user/search?query=#{encoded_name}")

      response.find { |u| u['displayName'].match(/#{Regexp.escape(name)}/i) }
    end

    def request(method, endpoint, body = nil)
      super do |request|
        request['Authorization'] = "Basic #{token}"
        request['Content-Type'] = 'application/json'
      end
    end

    def map_issue(raw_data)
      Models::JiraIssue.new(raw_data)
    end
  end
end
