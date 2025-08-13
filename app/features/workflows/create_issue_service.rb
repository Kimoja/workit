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
        valid_attribute_or_ask(:title, 'Issue title is required') { title&.strip&.present? }
        valid_attribute_or_ask(:project_key, 'Project key is required') { project_key&.strip&.present? }
        valid_attribute_or_ask(:issue_type, 'Issue type is required') { issue_type&.strip&.present? }
        valid_attribute_or_ask(:assignee_name, 'Assignee name is required') { assignee_name&.strip&.present? }
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
        find_board
      end

      memo def board_id
        board['id']
      end

      memo def board_type
        board['type']
      end

      memo def user_id
        find_user_id
      end

      memo def sprint_field_id
        board_type == 'scrum' ? find_sprint_field_id : nil
      end

      memo def sprint_id
        board_type == 'scrum' ? find_active_sprint : nil
      end

      def find_board
        board = issue_client.fetch_board_by_project_key(project_key)
        return board if board

        Log.error "Board '#{project_key}' not found"
        Log.pad 'Available boards:'
        boards.each { |b| Log.pad "- #{b['project_key']} (#{b['type']})" }

        raise "Board '#{project_key}' not found"
      end

      def find_user_id
        user = issue_client.fetch_user_by_name(assignee_name)
        return user['accountId'] if user

        Log.warn "User '#{name}' not found, issue will be unassigned"
        nil
      end

      def find_active_sprint
        sprint = issue_client.fetch_active_sprint(board_id)
        return sprint if sprint

        Log.warn "Error searching for sprint: #{e.message}"
        Log.pad 'Issue will be created in backlog'
        nil
      end

      def find_sprint_field_id
        id = issue_client.find_sprint_field_id
        return id if id

        Log.warn "Error searching for sprint field_id: #{e.message}"
        Log.pad 'Issue will be created in backlog'
        nil
      end

      def validate_issue_type
        available_types = issue_client.fetch_issue_types_for_project(project_key)

        unless available_types
          Log.warn 'Unable to validate issue type, using without validation'
          return issue_type
        end

        exact_match = available_types.find { |type| type.downcase == issue_type.downcase }
        return exact_match if exact_match

        partial_match = available_types.find { |type| type.downcase.include?(issue_type.downcase) }
        if partial_match
          Log.info "Issue type found: '#{partial_match}' (partial match)"
          return partial_match
        end

        # No match found
        Log.warn "Issue type '#{issue_type}' not found"
        Log.pad "Available types for project #{project_key}:"
        available_types.each { |type| Log.pad "- #{type}" }

        Log.warn "Using specified type without validation: #{issue_type}"

        issue_type
      end
    end
  end
end
