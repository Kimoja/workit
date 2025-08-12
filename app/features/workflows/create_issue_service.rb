module Features
  module Workflows
    class CreateIssueService < Service
      attr_reader :title, :board_name, :issue_type, :assignee_name, :issue_client

      def call
        summary

        valid_attributes!
        issue = create_issue
        add_to_cache(issue)
        Open.browser(issue.url)

        report(issue)
      end

      private

      def summary
        Log.info 'Creating Issue'
        Log.pad "- Board: #{board_name}"
        Log.pad "- Title: #{title}"
        Log.pad "- Type: #{issue_type}"
        Log.pad "- Assignee: #{assignee_name}"
      end

      def valid_attributes!
        raise 'Issue title is required' if title.nil? || title.strip.empty?
        raise 'Board name is required' if board_name.nil? || board_name.strip.empty?
        raise 'Issue type is required' if issue_type.nil? || issue_type.strip.empty?
        raise 'Assignee name is required' if assignee_name.nil? || assignee_name.strip.empty?
      end

      def board_id
        @board_id ||= find_board_id
      end

      def board_info
        @board_info ||= find_board_info
      end

      def board_type
        @board_type ||= board_info['type']
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
          Log.info "Board '#{board_name}' found in cache"
          return cached_result['id']
        end

        Log.info "Searching for board '#{board_name}'..."

        boards = issue_client.fetch_boards
        board = boards.find { |b| b['name'].match(/#{Regexp.escape(board_name)}/i) }

        unless board
          Log.error "Board '#{board_name}' not found"
          Log.pad 'Available boards:'
          boards.each { |b| Log.pad "- #{b['name']} (#{b['type']})" }
          raise
        end

        Log.info "Board found: ID #{board['id']} (Type: #{board['type']})"

        Cache.set(
          cache_key, value: {
            'id' => board['id'],
            'type' => board['type']
          }
        )

        board['id']
      end

      def find_board_info
        cache_key = "board_info_#{board_id}"

        cached_result = Cache.get(cache_key)
        if cached_result
          Log.info 'Board information found in cache'
          Log.pad "Board type: #{cached_result['type']}, associated project: #{cached_result['project_key']}"
          return cached_result
        end

        Log.info 'Retrieving board information...'

        board = issue_client.fetch_board(board_id)
        board_type = board['type'].downcase
        project_key = extract_project_key(board_id, board)

        raise 'Unable to determine project associated with board' unless project_key

        Log.info 'Board information found in cache'
        Log.pad "Board type: #{board_type}, associated project: #{project_key}"

        result = {
          'type' => board_type,
          'project_key' => project_key
        }

        Cache.set(cache_key, value: result)

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
          Log.warn "Error, unable to retrieve board configuration: #{e.message}"
        end

        nil
      end

      def find_active_sprint
        Log.info 'Searching for active sprint...'

        active_sprint = issue_client.fetch_active_sprint(board_id)

        if active_sprint
          Log.info "Active sprint found: '#{active_sprint['name']}' (ID: #{active_sprint['id']})"
          return active_sprint['id']
        end

        Log.warn 'No active sprint found'
        nil
      rescue StandardError => e
        Log.warn "Error searching for sprint: #{e.message}"
        Log.pad 'Issue will be created in backlog'
        nil
      end

      def find_sprint_field_id
        cache_key = 'sprint_field_id'

        # Cache verification
        cached_result = Cache.get(cache_key)
        if cached_result
          Log.info 'Sprint field ID found in cache'
          Log.pad 'Scrum board detected - sprint management enabled'
          Log.pad "Sprint field found: #{cached_result}"
          return cached_result
        end

        Log.info 'Searching for Sprint field ID...'
        Log.pad 'Scrum board detected - sprint management enabled'

        begin
          field = issue_client.fetch_field_by_name('Sprint')

          unless field
            Log.warn 'Sprint field not found - board without sprints or missing configuration'
            return nil
          end

          Log.info "Sprint field found: #{field['id']}"

          Cache.set(cache_key, value: field['id'])
        rescue StandardError => e
          Log.warn "Error searching for sprint field: #{e.message}"
          nil
        end
      end

      def find_user_id
        cache_key = "user_id_#{assignee_name.downcase.gsub(/\s+/, '_')}"

        # Cache verification
        cached_result = Cache.get(cache_key)
        if cached_result
          if cached_result == 'not_found' # String instead of symbol
            Log.warn "User '#{assignee_name}' not found (cache), issue will be unassigned"
            return nil
          else
            Log.info "User '#{assignee_name}' found in cache"
            return cached_result['account_id']
          end
        end

        Log.info "Searching for user '#{assignee_name}'..."

        user = issue_client.fetch_user_by_name(assignee_name)

        unless user
          Log.warn "User '#{assignee_name}' not found, issue will be unassigned"
          Cache.set(cache_key, 'not_found')
          return nil
        end

        Log.info "User found: #{user['displayName']}"

        # Cache with string keys
        Cache.set(
          cache_key, value: {
            'account_id' => user['accountId'],
            'display_name' => user['displayName']
          }
        )

        user['accountId']
      end

      def validate_issue_type
        cache_key = "issue_types_#{project_key}"

        # Cache verification
        cached_types = Cache.get(cache_key)
        if cached_types
          Log.info "Issue types for project #{project_key} found in cache"
          return find_matching_issue_type(cached_types)
        end

        Log.info "Validating issue type '#{issue_type}' for project #{project_key}..."

        begin
          issue_types = issue_client.fetch_issue_types(project_key)

          unless issue_types
            Log.warn 'Unable to validate issue type, using without validation'
            return issue_type
          end

          Cache.set(cache_key, value: issue_types)

          find_matching_issue_type(issue_types)
        rescue StandardError => e
          Log.warn "Error validating issue type: #{e.message}"
          Log.pad "Using specified type without validation: #{issue_type}"
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
          Log.info "Issue type found: '#{partial_match}' (partial match)"
          return partial_match
        end

        # No match found
        Log.error "Issue type '#{issue_type}' not found"
        Log.pad "Available types for project #{project_key}:"
        available_types.each { |type| Log.pad "- #{type}" }

        raise "Issue type '#{issue_type}' not found"
      end

      def create_issue
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
          Log.info 'Adding to active sprint'
        else
          Log.info 'Creating in backlog'
        end

        payload[:fields][:assignee] = { id: user_id } if user_id

        Log.info 'Creating issue...'

        binding.pry
        raise

        issue_client.create_issue(payload)
      end

      def add_to_cache(issue)
        Cache.set(
          'last_issue', value: {
            'url' => issue.url,
            'issue_key' => issue.key
          }
        )
      end

      def report(issue)
        Log.success "Issue created successfully: #{issue.key}"
        Log.info "URL: #{issue.url}"

        return Log.info 'Issue added to project backlog' if board_type == 'scrum' && sprint_id.nil?
        return Log.info 'Issue added to active sprint' if board_type == 'scrum' && sprint_id

        Log.info 'Issue added to Kanban board'
      end
    end
  end
end
