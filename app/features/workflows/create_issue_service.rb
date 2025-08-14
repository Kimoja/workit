module Features
  module Workflows
    class CreateIssueService < Service
      attr_reader :title, :project_key, :issue_type, :assignee_name, :issue_client

      def call
        valid_attributes!
        summary
        issue = create_issue
        add_to_cache(issue)
        Open.browser(issue.url)
        report(issue)

        issue.url
      end

      private

      def valid_attributes!
        valid_attribute_or_ask(
          attribute: :title,
          text: 'Issue title is required'
        ) { title&.strip&.present? }

        valid_attribute_or_select(
          attribute: :project_key,
          text: 'Project key is required',
          options: issue_client.fetch_project_keys,
          default: Config.get("@issue_provider", "default_project_key")
        ) { project_key&.strip&.present? }

        valid_attribute_or_select(
          attribute: :issue_type,
          text: 'Issue type is required',
          options: issue_types,
          default: Config.get("@issue_provider", "default_issue_type")
        ) { issue_type&.strip&.present? }

        valid_attribute_or_select(
          attribute: :assignee_name,
          text: 'Assignee name is required',
          options: issue_client.fetch_assignable_users(project_key),
          default: Config.get("@issue_provider", "default_assignee_name")
        ) { assignee_name&.strip&.present? }
      end

      def summary
        Log.start 'Creating Issue'
        Log.pad "- Project Key: #{project_key}"
        Log.pad "- Title: #{title}"
        Log.pad "- Type: #{issue_type}"
        Log.pad "- Assignee: #{assignee_name}"
      end

      def create_issue
        validated_issue_type = validate_issue_type

        payload = {
          fields: {
            project: { key: project_key },
            summary: title,
            description: 'Issue created automatically via Ruby CLI script',
            issuetype: { name: validated_issue_type }
          }
        }

        payload[:fields][sprint_field_id] = sprint_id if sprint_id && sprint_field_id
        payload[:fields][:assignee] = { id: user_id } if user_id

        binding.pry
        raise

        issue_client.create_issue(payload)
      end

      def validate_issue_type
        unless issue_types
          Log.warn 'Unable to validate issue type, using without validation'
          return issue_type
        end

        exact_match = issue_types.find { |type| type.downcase == issue_type.downcase }
        return exact_match if exact_match

        partial_match = issue_types.find { |type| type.downcase.include?(issue_type.downcase) }
        if partial_match
          Log.info "Issue type found: '#{partial_match}' (partial match)"
          return partial_match
        end

        # No match found
        Log.warn "Issue type '#{issue_type}' not found"
        Log.pad "Available types for project #{project_key}:"
        issue_types.each { |type| Log.pad "- #{type}" }

        Log.warn "Using specified type without validation: #{issue_type}"

        issue_type
      end

      def add_to_cache(issue)
        Cache.set(
          'last_issue_created',
          value: {
            'url' => issue.url,
            'issue_key' => issue.key
          }
        )
      end

      def report(issue)
        Log.success "Issue created successfully: #{issue.key}"
        Log.pad "URL: #{issue.url}"

        return Log.pad 'Issue added to project backlog' if board_type == 'scrum' && sprint_id.nil?
        return Log.pad 'Issue added to active sprint' if board_type == 'scrum' && sprint_id

        Log.pad 'Issue added to Kanban board'
      end

      ### STATE ###

      memo def board
        board = issue_client.fetch_project_by_key(project_key)
        return board if board

        Log.error "Board '#{project_key}' not found"
        Log.pad 'Available boards:'
        boards.each { |b| Log.pad "- #{b['project_key']} (#{b['type']})" }

        raise "Board '#{project_key}' not found"
      end

      memo def board_id
        board['id']
      end

      memo def board_type
        board['type']
      end

      memo def user_id
        user = issue_client.fetch_user_by_name(assignee_name)
        return user['accountId'] if user

        Log.warn "User '#{assignee_name}' not found, issue will be unassigned"
        nil
      end

      memo def issue_types
        issue_client.fetch_issue_types_for_project(project_key)
      end

      memo def sprint_field_id
        return unless board_type == 'scrum'

        id = issue_client.find_sprint_field_id
        return id if id

        Log.warn "Error searching for sprint field_id: #{e.message}"
        Log.pad 'Issue will be created in backlog'
        nil
      end

      memo def sprint_id
        return unless board_type == 'scrum'

        sprint = issue_client.fetch_active_sprint(board_id)
        return sprint if sprint

        Log.warn "Error searching for sprint: #{e.message}"
        Log.pad 'Issue will be created in backlog'
        nil
      end
    end
  end
end
