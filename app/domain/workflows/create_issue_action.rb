module Domain
  module Workflows
    class CreateIssueAction
      include Action
      include Domain

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
          options: proc { issue_client.fetch_project_keys },
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
          options: proc { issue_client.fetch_project_user_names(project_key) },
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
        issue_client.create_issue(
          project_key:,
          title:,
          issue_type: validate_issue_type,
          user_id:,
          sprint_id:,
          sprint_field_id: sprint_id ? sprint_field_id : nil
        )
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

        Log.warn "Issue type '#{issue_type}' not found"
        Log.pad "Available types for project '#{project_key}':"
        issue_types.each { |type| Log.pad "- #{type}" }

        Log.warn "Using specified type without validation: '#{issue_type}'"
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

      memo def project
        project = issue_client.fetch_project(project_key)
        return project if project

        Log.error "Project '#{project_key}' not found"
        Log.pad 'Available projects:'
        issue_client.fetch_projects.each { |key, proj| Log.pad "- #{key} (#{proj['board_type']})" }

        raise "Project '#{project_key}' not found"
      end

      memo def board_id
        project['board_id']
      end

      memo def board_type
        project['board_type']
      end

      memo def user_id
        user_id = issue_client.fetch_user_id(assignee_name)
        return user_id if user_id

        Log.warn "User '#{assignee_name}' not found, issue will be unassigned"
        nil
      end

      memo def issue_types
        issue_client.fetch_issue_types_for_project(project_key)
      end

      memo def sprint_field_id
        return unless board_type == 'scrum'

        begin
          id = issue_client.fetch_sprint_field_id
          return id if id

          Log.warn 'Sprint field ID not found'
          Log.pad 'Issue will be created in backlog'
          nil
        rescue StandardError => e
          Log.warn "Error searching for sprint field ID: #{e.message}"
          Log.pad 'Issue will be created in backlog'
          nil
        end
      end

      memo def sprint_id
        return unless board_type == 'scrum'

        begin
          sprint = issue_client.fetch_active_sprint(board_id)
          return sprint if sprint

          Log.info 'No active sprint found'
          Log.pad 'Issue will be created in backlog'
          nil
        rescue StandardError => e
          Log.warn "Error searching for active sprint: #{e.message}"
          Log.pad 'Issue will be created in backlog'
          nil
        end
      end
    end
  end
end
