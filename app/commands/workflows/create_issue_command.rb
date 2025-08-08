module Commands
  module Workflows
    class CreateIssueCommand
      include Command

      self.function = "create-issue"
      self.aliases = ["issue"]
      self.summary = "Create issue via API with automatic sprint assignment"

      def call
        options = parse_options

        title = ARGV[0]
        project_key = options[:project_key]
        issue_type = options[:type]
        user_name = options[:user_name]

        issue_client = Clients::Issues.build_from_config!

        Domain::Workflows.create_issue(
          title: title,
          project_key: project_key,
          issue_type: issue_type,
          user_name: user_name,
          issue_client: issue_client
        )
      end

      private

      def parse_options
        options = {
          project_key: nil,
          type: nil,
          user_name: nil
        }

        OptionParser.new do |opts|
          opts.banner = "Usage: issue [OPTIONS] \"ISSUE_TITLE\"\n\n#{self.class.summary}"
          opts.separator ''
          opts.separator 'Arguments:'
          opts.separator '  ISSUE_TITLE  Title of the issue to create (required)'
          opts.separator ''
          opts.separator 'Options:'

          opts.on('-p', '--project-key PROJECT_KEY',
                  'Issue project key name (default: from config.json)') do |project_key|
            options[:project_key] = project_key
          end

          opts.on('-t', '--type TYPE', 'Issue type (default: from config.json)',
                  'Common types: Task, Story, Bug, Epic, Subtask') do |type|
            options[:type] = type
          end

          opts.on('-u', '--user_name USER_NAME', 'User name (default: from config.json)',
                  'Specify who will be assigned to this issue') do |user_name|
            options[:user_name] = user_name
          end

          opts.on('-h', '--help', 'Show this help') do
            show_help(opts)
            exit
          end
        end.parse!

        options
      end

      def show_help(opts)
        Log.log opts
        Log.log ''
        Log.log 'Examples:'
        Log.log "  #{self.class.summary} \"Fix login bug\""
        Log.log "  #{self.class.summary} -p KRAFT \"Implement new feature\""
        Log.log "  #{self.class.summary} -t Bug \"Fix image display\""
        Log.log "  #{self.class.summary} -u john.doe \"Review code changes\""
        Log.log "  #{self.class.summary} -p KRAFT -t Story -u jane.smith \"Add new dashboard\""
        Log.log ''
        Log.log 'Behavior:'
        Log.log '  • Creates issue in specified or default project'
        Log.log '  • Assigns to specified or default user'
        Log.log '  • Adds to active sprint or backlog based on board type'
        Log.log ''
        Log.log 'Configuration:'
        Log.log '  • Uses config.json for default values'
        Log.log '  • Default project, issue type, and user can be configured'
        Log.log ''
        Log.log 'Board types:'
        Log.log '  • Scrum: issue added to active sprint or backlog'
        Log.log '  • Kanban: issue added directly to board'
        Log.log ''
        Log.log 'Assignment:'
        Log.log '  • Use -u to specify user name'
        Log.log '  • Leave unassigned if no default configured'
      end
    end
  end
end
