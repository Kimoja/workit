module Features
  class CreateIssueService < Service
    attr_reader :title, :board_name, :issue_type, :assignee_name, :issue_client

    def call
      issue = create_issue
      add_to_cache(issue)
      display_success(issue)
      Open.browser(issue.url)
    end

    private

    def board_id
      @board_id ||= find_board_id
    end

    def board_info
      @board_id ||= find_board_info
    end

    def board_type
      @project_key ||= board_info['type']
    end

    def project_key
      @project_key ||= board_info['project_key']
    end

    def sprint_field_id
      @sprint_field_id ||= board_type == 'scrum' ? find_sprint_field_id : nil
    end

    def sprint_id
      @sprint_id ||= board_type == 'scrum' ? find_active_sprint : nil
    end

    def user_id
      @user_id ||= find_user_id
    end

    def find_board_id
      cache_key = "board_id_#{board_name.downcase.gsub(/\s+/, '_')}"

      cached_result = Cache.get(cache_key)
      if cached_result
        Log.log "🔍 Board '#{board_name}' found in cache"
        Log.success "Board found: ID #{cached_result['id']} (Type: #{cached_result['type']})"
        return cached_result['id']
      end

      Log.log "🔍 Searching for board '#{board_name}'..."

      boards = issue_client.fetch_boards
      board = boards.find { |b| b['name'].match(/#{Regexp.escape(board_name)}/i) }

      unless board
        Log.error "Board '#{board_name}' not found"
        Log.log 'Available boards:'
        boards.each { |b| Log.log "  - #{b['name']} (#{b['type']})" }
        raise
      end

      Log.success "Board found: ID #{board['id']} (Type: #{board['type']})"

      Cache.set(cache_key, {
                  'id' => board['id'],
                  'type' => board['type']
                })

      board['id']
    end

    def find_board_info
      cache_key = "board_info_#{board_id}"

      cached_result = Cache.get(cache_key)
      if cached_result
        Log.log '🔍 Board information found in cache'
        Log.success "Board type: #{cached_result['type']}"
        Log.success "Associated project: #{cached_result['project_key']}"
        return cached_result
      end

      Log.log '🔍 Retrieving board information...'

      board = issue_client.fetch_board(board_id)
      board_type = board['type'].downcase
      project_key = extract_project_key(board_id, board)

      raise 'Unable to determine project associated with board' unless project_key

      Log.success "Board type: #{board_type}"
      Log.success "Associated project: #{project_key}"

      result = {
        'type' => board_type,
        'project_key' => project_key
      }

      Cache.set(cache_key, result)

      result
    end

    def extract_project_key(board_id, board)
      # Method 1: Directly from board information
      return board['location']['projectKey'] if board['location'] && board['location']['projectKey']

      # Method 2: Via board configuration
      begin
        board_configuration = issue_client.fetch_board_configuration(board_id)
        if board_configuration['location'] && board_configuration['location']['projectKey']
          return board_configuration['location']['projectKey']
        end
      rescue StandardError => e
        Log.warn "Unable to retrieve board configuration: #{e.message}"
      end

      nil
    end

    def find_active_sprint
      Log.info '🔍 Searching for active sprint...'

      active_sprint = issue_client.fetch_active_sprint(board_id)

      if active_sprint
        Log.success "Active sprint found: '#{active_sprint['name']}' (ID: #{active_sprint['id']})"
        return active_sprint['id']
      end

      Log.warn 'No active sprint found'
      nil
    rescue StandardError => e
      Log.warn "Error searching for sprint: #{e.message}"
      Log.log '📦 Issue will be created in backlog'
      nil
    end

    def find_sprint_field_id
      cache_key = 'sprint_field_id'

      # Cache verification
      cached_result = Cache.get(cache_key)
      if cached_result
        Log.log '🔍 Sprint field ID found in cache'
        Log.log '📋 Scrum board detected - sprint management enabled'
        Log.success "Sprint field found: #{cached_result}"
        return cached_result
      end

      Log.log '🔍 Searching for Sprint field ID...'
      Log.log '📋 Scrum board detected - sprint management enabled'

      begin
        field = issue_client.fetch_field_by_name('Sprint')

        unless field
          Log.warn 'Sprint field not found - board without sprints or missing configuration'
          return nil
        end

        Log.success "Sprint field found: #{field['id']}"

        Cache.set(cache_key, field['id'])
      rescue StandardError => e
        Log.warn "Error searching for Sprint field: #{e.message}"
        nil
      end
    end

    def find_user_id
      cache_key = "user_id_#{assignee_name.downcase.gsub(/\s+/, '_')}"

      # Cache verification
      cached_result = Cache.get(cache_key)
      if cached_result
        Log.log "🔍 User '#{assignee_name}' found in cache"
        if cached_result == 'not_found' # String instead of symbol
          Log.warn "User '#{assignee_name}' not found (cache), issue will be unassigned"
          return nil
        else
          Log.success "User found: #{cached_result['display_name']}"
          return cached_result['account_id']
        end
      end

      Log.log "🔍 Searching for user '#{assignee_name}'..."

      user = issue_client.fetch_user_by_name(assignee_name)

      unless user
        Log.warn "User '#{assignee_name}' not found, issue will be unassigned"
        # Cache negative result (string)
        Cache.set(cache_key, 'not_found')
        return nil
      end

      Log.success "User found: #{user['displayName']}"

      # Cache with string keys
      Cache.set(cache_key, {
                  'account_id' => user['accountId'],
                  'display_name' => user['displayName']
                })

      user['accountId']
    end

    def validate_issue_type
      cache_key = "issue_types_#{project_key}"

      # Cache verification
      cached_types = Cache.get(cache_key)
      if cached_types
        Log.log "🔍 Issue types for project #{project_key} found in cache"
        return find_matching_issue_type(cached_types)
      end

      Log.log "🔍 Validating issue type '#{issue_type}' for project #{project_key}..."

      begin
        issue_types = issue_client.fetch_issue_types(project_key)

        unless issue_types
          Log.warn 'Unable to validate issue type, using without validation'
          return issue_type
        end

        Cache.set(cache_key, issue_types)

        find_matching_issue_type(issue_types)
      rescue StandardError => e
        Log.warn "Error validating issue type: #{e.message}"
        Log.log "Using specified type without validation: #{issue_type}"
        issue_type
      end
    end

    def find_matching_issue_type(available_types)
      # Exact search first
      exact_match = available_types.find { |type| type.downcase == issue_type.downcase }
      return exact_match if exact_match

      # Partial search if no exact match
      partial_match = available_types.find { |type| type.downcase.include?(issue_type.downcase) }
      if partial_match
        Log.success "Issue type found: '#{partial_match}' (partial match)"
        return partial_match
      end

      # No match found
      Log.error "Issue type '#{issue_type}' not found"
      Log.log "Available types for project #{project_key}:"
      available_types.each { |type| Log.log "  - #{type}" }
      raise 'Invalid issue type'
    end

    def create_issue
      Log.log '🎫 Creating issue...'

      validated_type = validate_issue_type

      payload = {
        fields: {
          project: { key: project_key },
          summary: title,
          description: 'Issue created automatically via Ruby CLI script',
          issuetype: { name: validated_type }
        }
      }

      if sprint_id && sprint_field_id
        payload[:fields][sprint_field_id] = sprint_id
        Log.log '📌 Adding to active sprint'
      else
        Log.log '📦 Creating in backlog'
      end

      payload[:fields][:assignee] = { id: user_id } if user_id

      binding.pry
      raise

      issue_client.create_issue(payload)
    end

    def add_to_cache(issue)
      Cache.set('last_issue', {
                  'url' => issue.url,
                  'issue_key' => issue.key
                })
    end

    def display_success(issue)
      Log.success "Issue created successfully: #{issue.key}"
      Log.log "🔗 URL: #{issue.url}"

      if board_type == 'scrum' && sprint_id.nil?
        Log.log '📦 Issue added to project backlog'
      elsif board_type == 'scrum' && sprint_id
        Log.log '🏃 Issue added to active sprint'
      else
        Log.log '📋 Issue added to Kanban board'
      end

      Log.log ''
      Log.success '🎉 Done!'
    end
  end
end
