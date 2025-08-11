module Commands
  class CreateIssueCommand
    def call
      options = {
        board: nil,
        type: nil
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} [OPTIONS] \"ISSUE_TITLE\""
        opts.separator ''
        opts.separator 'Arguments:'
        opts.separator '  ISSUE_TITLE  Title of the isse to create (required)'
        opts.separator ''
        opts.separator 'Options:'

        opts.on('-b', '--board BOARD', 'Issue board name (default: from config.json)') do |board|
          options[:board] = board
        end

        opts.on('-t', '--type TYPE', 'Issue type (default: from config.json)',
                'Common types: Task, Story, Bug, Epic, Subtask') do |type|
          options[:type] = type
        end

        opts.on('-h', '--help', 'Show this help') do
          Log.log opts
          Log.log ''
          Log.log 'Examples:'
          Log.log '  issue "Fix login bug"'
          Log.log '  issue -b KRAFT "Implement new feature"'
          Log.log '  issue -t Bug "Fix image display"'
          Log.log '  issue -b BT -t Task "User interface"'
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
          exit
        end

        opts.on('-v', '--version', 'Show version') do
          Log.log 'Issue'
          exit
        end
      end.parse!

      title = ARGV[0]
      board_name = options[:board] || config.jira.default_board
      issue_type = options[:type] || config.jira.default_issue_type
      assignee_name = config.jira.assignee_name

      issue_client = JiraClient.build_from_config!(config)

      validate_create_issue_command!(title:, board_name:, issue_type:, assignee_name:)

      Log.log '🚀 Creating Issue'
      Log.log "Board: #{board_name}"
      Log.log "Title: #{title}"
      Log.log "Type: #{issue_type}"
      Log.log "Assignee: #{assignee_name}"
      Log.log ''

      create_issue_service = CreateIssueService.new(
        title:,
        board_name:,
        issue_type:,
        assignee_name:,
        issue_client:
      )

      create_issue_service.call
    end

    def validate_create_issue_command!(title:, board_name:, issue_type:, assignee_name:)
      raise 'Issue title is required' if title.nil? || title.strip.empty?

      raise 'Board name is required' if board_name.nil? || board_name.strip.empty?

      raise 'Issue type is required' if issue_type.nil? || issue_type.strip.empty?

      raise 'Assignee name is required' if assignee_name.nil? || assignee_name.strip.empty?

      Log.success 'Input parameters validated'
    end
  end
end
