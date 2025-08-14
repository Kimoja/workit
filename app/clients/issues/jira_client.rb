module Clients
  module Issues
    class JiraClient < HttpClient
      def self.build_from_config!
        url = Config.get('jira', 'url')
        email = Config.get('jira', 'email')
        token = Config.get('jira', 'token')

        raise "Configuration parameter 'jira.url' is required" if url.nil? || url.strip.empty?

        unless url.match?(%r{\Ahttps?://.+\.atlassian\.net\z})
          raise "Jira URL doesn't appear to be a standard Atlassian URL. Configured URL: #{url}"
        end

        raise "Configuration parameter 'jira.email' is required" if email.nil? || email.strip.empty?
        raise "Configuration parameter 'jira.token' is required" if token.nil? || token.strip.empty?

        new(base_url: url, token: Base64.strict_encode64("#{email}:#{token}"))
      end

      def fetch_project(project_key)
        Log.info "Searching for project '#{project_key}'..."

        project = fetch_projects[project_key]

        if project
          Log.info "Project '#{project_key}' found"
          return project
        end

        Log.warn "Project '#{project_key}' not found"
        nil
      end

      def fetch_projects
        Log.info "Fetching projects..."

        cache_keys = %w[jira projects]
        projects = Cache.get(*cache_keys)
        if projects
          Log.info "Projects found in cache"
          return projects
        end

        boards = get('/rest/agile/1.0/board')['values']

        projects = boards.each_with_object({}) do |board, obj|
          next unless board['location'] && board['location']['projectKey']

          project_key = board['location']['projectKey']

          obj[project_key] = {
            'board_id' => board['id'],
            'board_type' => board['type'],
            'board_name' => board['name']
          }
        end

        Log.info "#{projects.size} projects found"
        Cache.set(*cache_keys, value: projects, ttl: 1.week)
      end

      def fetch_issue_types_for_project(project_key)
        Log.info "Searching issue types for project '#{project_key}'..."

        cache_keys = ["jira", "projects", project_key, "issue_types"]
        cached_types = Cache.get(*cache_keys)

        if cached_types
          Log.info "Issue types for project '#{project_key}' found in cache"
          return cached_types
        end

        project = get(
          "/rest/api/2/issue/createmeta?projectKeys=#{project_key}&expand=projects.issuetypes"
        )['projects'].first

        if project
          Log.info "Issue types found for project '#{project_key}'"
          issue_types = project['issuetypes'].map { |type| type['name'] }
          return Cache.set(*cache_keys, value: issue_types, ttl: 1.week)
        end

        Log.warn "Issue types not found for project '#{project_key}'"
        nil
      end

      def fetch_sprint_field_id
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
          return Cache.set(*cache_keys, value: field['id'], ttl: 1.year)
        end

        Log.warn 'Sprint field not found'
        nil
      end

      def fetch_active_sprint(board_id)
        Log.info "Searching for active sprint on board #{board_id}..."

        active_sprint = get("/rest/agile/1.0/board/#{board_id}/sprint?state=active")['values'].first

        if active_sprint
          Log.info "Active sprint found: '#{active_sprint['name']}' (ID: #{active_sprint['id']})"
          return active_sprint['id']
        end

        Log.info 'No active sprint found'
        nil
      end

      def fetch_user_id(name)
        Log.info "Searching for user ID for '#{name}'..."

        cache_keys = %w[jira users]

        cached_result = Cache.get(*cache_keys, name)
        if cached_result
          Log.info "User '#{name}' found in cache"
          return cached_result
        end

        encoded_name = URI.encode_www_form_component(name)
        response = get("/rest/api/3/user/search?query=#{encoded_name}")
        user = response.find { |u| u['displayName'].match(/#{Regexp.escape(name)}/i) }

        if user
          Log.info "User found: #{user['displayName']}"
          return Cache.set(*cache_keys, user['displayName'], value: user['accountId'], ttl: 1.year)
        end

        Log.warn "User '#{name}' not found"
        nil
      end

      def fetch_project_user_names(project_key)
        Log.info "Fetching user names for project '#{project_key}'..."

        cache_keys = ["jira", "projects", project_key, "recent_users"]
        cached_users = Cache.get(*cache_keys)

        if cached_users
          Log.info "User names for project '#{project_key}' found in cache"
          return cached_users
        end

        jql = "project = #{project_key} AND updated >= -60d"
        encoded_jql = URI.encode_www_form_component(jql)

        recent_issues = get("/rest/api/2/search?jql=#{encoded_jql}&fields=assignee&maxResults=200")['issues']

        users = recent_issues
                .filter_map { |issue| issue.dig('fields', 'assignee') }
                .uniq { |assignee| assignee['accountId'] }

        users.each do |user|
          Cache.set("jira", "users", user['displayName'], value: user['accountId'], ttl: 1.year)
        end

        user_names = users
                     .map { |assignee| assignee['displayName'] }
                     .sort

        Log.info "Found #{user_names.size} user names for project '#{project_key}'"
        Cache.set(*cache_keys, value: user_names)
      end

      def fetch_user_issues(user_name, limit: 20)
        Log.info "Fetching recent issues for user '#{user_name}'..."

        user_id = fetch_user_id(user_name)
        unless user_id
          Log.warn "User '#{user_name}' not found, cannot fetch issues"
          return []
        end

        jql = "assignee = #{user_id} ORDER BY created DESC"
        encoded_jql = URI.encode_www_form_component(jql)

        response = get("/rest/api/2/search?jql=#{encoded_jql}&maxResults=#{limit}&fields=key,summary,status,created,priority,issuetype")
        issues = response['issues']

        if issues && !issues.empty?
          Log.success "Found #{issues.size} recent issues for user '#{user_name}'"

          issues.map { |issue| map_issue(issue) }
        else
          Log.info "No issues found for user '#{user_name}'"
          []
        end
      end

      def fetch_issue(key)
        Log.info "Fetching issue '#{key}'..."
        issue = map_issue(get("/rest/api/2/issue/#{key}"))
        Log.info "Issue '#{key}' retrieved successfully"
        issue
      end

      def create_issue(
        project_key:,
        title:,
        issue_type:,
        user_id:,
        sprint_field_id:,
        sprint_id:,
        description: 'Issue created automatically via Ruby CLI script'
      )
        Log.info 'Creating issue...'

        payload = {
          fields: {
            project: { key: project_key },
            summary: title,
            description:,
            issuetype: { name: issue_type }
          }
        }

        payload[:fields][sprint_field_id] = sprint_id if sprint_field_id && sprint_id
        payload[:fields][:assignee] = { accountId: user_id } if user_id

        binding.pry
        raise

        begin
          issue = post('/rest/api/2/issue', payload)
          Log.info "Issue created successfully: #{issue['key']}"
          map_issue(issue)
        rescue StandardError => e
          Log.error "Failed to create issue: #{e.message}"
          raise
        end
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
    end
  end
end
