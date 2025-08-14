module Commands
  class CreateIssueCommand
    include Command

    def call
      options = {
        project_key: nil,
        type: nil
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: issue [OPTIONS] \"ISSUE_TITLE\""
        opts.separator ''
        opts.separator 'Arguments:'
        opts.separator '  ISSUE_TITLE  Title of the isse to create (required)'
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
          Log.log opts
          Log.log ''
          Log.log 'Examples:'
          Log.log '  issue "Fix login bug"'
          Log.log '  issue -b KRAFT "Implement new feature"'
          Log.log '  issue -t Bug "Fix image display"'
          Log.log '  issue -u john.doe "Review code changes"'
          Log.log '  issue -b BT -t Task "User interface"'
          Log.log '  issue -b KRAFT -t Story -u jane.smith "Add new dashboard"'
          Log.log ''
          Log.log 'Configuration:'
          Log.log '  The command uses the config.json configuration file'
          Log.log ''
          Log.log 'Supported board types:'
          Log.log '  Scrum   - With sprints and backlog'
          Log.log '  Kanban  - No sprints, continuous flow'
          Log.log ''
          Log.log 'Sprint management:'
          Log.log '  • Scrum boards: issue added to active sprint or backlog'
          Log.log '  • Kanban boards: issue added directly to board'
          Log.log '  • No active sprint: issue added to backlog'
          Log.log ''
          Log.log 'Assignment:'
          Log.log '  • Use -u to specify user name'
          Log.log '  • Default user name comes from config.json'
          Log.log '  • Leave unassigned if no default configured'
          exit
        end
      end.parse!

      title = ARGV[0]
      project_key = options[:project_key]
      issue_type = options[:type]
      user_name = options[:user_name]

      issue_client = Clients::Issues.build_from_config!

      Domain::Workflows.create_issue(
        title:,
        project_key:,
        issue_type:,
        user_name:,
        issue_client:
      )
    end
  end
end
