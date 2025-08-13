module Clients
  module Issues
    class JiraClient < Client
      def self.build_from_config!
        url = Config.get('jira', 'url')
        email = Config.get('jira', 'email')
        token = Config.get('jira', 'token')

        raise "Configuration parameter 'jira.url' is required" if url.nil? || token.strip.empty?

        unless url.match?(%r{\Ahttps?://.+\.atlassian\.net\z})
          raise "Warning: Jira URL doesn't appear to be a standard Atlassian URL, configured URL: #{url}"
        end

        raise "Configuration parameter 'jira.email' is required" if email.nil? || email.strip.empty?
        raise "Configuration parameter 'jira.token' is required" if token.nil? || token.strip.empty?

        new(base_url: url, token: Base64.strict_encode64("#{email}:#{token}"))
      end

      def fetch_board_by_project_key(project_key)
        Log.info "Searching for board '#{project_key}'..."

        project_key_normalized = normalize_project_key(project_key)
        board = Cache.get("jira", "boards", project_key_normalized)

        if board
          Log.info "Board '#{project_key}' found in cache"
          return board
        end

        fetch_boards_and_refresh_cache
        board = Cache.get("jira", "boards", project_key_normalized)

        if board
          Log.info "Board '#{project_key}' found"
          return board
        end

        Log.info "Board '#{project_key}' not found"
        nil
      end

      def fetch_project_keys
        Log.info "Fetching project_keys..."

        boards = Cache.get("jira", "boards")
        if boards
          Log.info "Project keys found in cache"
          return boards.keys
        end

        fetch_boards_and_refresh_cache
        boards = Cache.get("jira", "boards")

        Log.info "#{boards.size} Project keys found"

        boards.keys.sort
      end

      def fetch_boards_and_refresh_cache
        Log.info "Fetching available boards..."

        boards = get('/rest/agile/1.0/board')['values']

        boards.filter_map do |board|
          project_key = extract_board_project_key(board)
          next unless project_key

          Cache.set(
            "jira", "boards", project_key,
            value: {
              'id' => board['id'],
              'type' => board['type'],
              'name' => board['name'],
              'project_key' => project_key
            }
          )
        end
      end

      def find_sprint_field_id
        Log.info 'Searching for Sprint field ID...'

        cache_keys = %w[jira sprint_field_id]

        cached_result = Cache.get(*cache_keys)
        if cached_result
          Log.info 'Sprint field ID found in cache'
          return cached_result
        end

        field = get('/rest/api/2/field').find { |f| f['name'] == 'Sprint' }

        if field
          Log.info "Sprint field found: #{field['id']}"
          return Cache.set(*cache_keys, value: field['id'])
        end

        Log.warn 'Sprint field not found'
        nil
      end

      def fetch_user_by_name(name)
        Log.info "Searching for user '#{name}'..."

        name_normalized = normalize_name(name)
        cache_keys = %w[jira users]

        cached_result = Cache.get(*cache_keys, name_normalized)
        if cached_result
          Log.info "User '#{name}' found in cache"
          return cached_result['account_id']
        end

        encoded_name = URI.encode_www_form_component(name)
        response = get("/rest/api/3/user/search?query=#{encoded_name}")
        user = response.find { |u| u['displayName'].match(/#{Regexp.escape(name)}/i) }

        if user
          Log.info "User found: #{user['displayName']}"
          return Cache.set(
            *cache_keys, normalize_name(user['displayName']), value: {
              'account_id' => user['accountId'],
              'display_name' => user['displayName']
            }
          )
        end

        Log.info "User '#{name}' not found"
        nil
      end

      def fetch_issue_types_for_project(project_key)
        Log.info "Searching issue types for project #{project_key}..."

        cache_keys = ["jira", "issue_types", project_key]
        cached_types = Cache.get(*cache_keys)

        if cached_types
          Log.info "Issue types for project #{project_key} found in cache"
          return cached_types
        end

        project = get(
          "/rest/api/2/issue/createmeta?projectKeys=#{project_key}&expand=projects.issuetypes"
        )['projects'].first

        if project
          Log.info "Issue types found for project '#{project_key}'"
          issue_types = project['issuetypes'].map { |type| type['name'] }
          return Cache.set(*cache_keys, value: issue_types)
        end

        Log.info "Issue types not found for project '#{project_key}'"
        nil
      end

      def fetch_active_sprint(board_id)
        Log.info 'Searching for active sprint...'

        active_sprint = get("/rest/agile/1.0/board/#{board_id}/sprint?state=active")['values'].first

        if active_sprint
          Log.info "Active sprint found: '#{active_sprint['name']}' (ID: #{active_sprint['id']})"
          return active_sprint['id']
        end

        Log.info 'No active sprint found'
        nil
      end

      def create_issue(payload)
        Log.info 'Creating issue...'

        begin
          issue = post('/rest/api/2/issue', payload)
          Log.info "Issue created successfully: #{issue['key']}"
          map_issue(issue)
        rescue StandardError => e
          Log.error "Error creating issue: #{e.message}"
          raise
        end
      end

      ### -----------###

      def fetch_issue(key)
        map_issue(get("/rest/api/2/issue/#{key}"))
      end

      def request(method, endpoint, body: nil, query: nil)
        super do |request|
          request['Authorization'] = "Basic #{token}"
          request['Content-Type'] = 'application/json'
        end
      end

      private

      def map_issue(raw_data)
        Models::JiraIssue.new(raw_data)
      end

      def normalize_project_key(project_key)
        project_key.downcase.gsub(/\s+/, '_')
      end

      def extract_board_project_key(board)
        return unless board['location'] && board['location']['projectKey']

        normalize_project_key(board['location']['projectKey'])
      end

      def normalize_name(name)
        name.downcase.gsub(/\s+/, '_')
      end
    end
  end
end