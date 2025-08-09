require_relative '../clients/jira_client'
require_relative '../services/create_issue_service'

def create_issue_command
  options = {
    board: nil,
    type: nil
  }
  
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS] \"ISSUE_TITLE\""
    opts.separator ""
    opts.separator "Arguments:"
    opts.separator "  ISSUE_TITLE  Title of the isse to create (required)"
    opts.separator ""
    opts.separator "Options:"
    
    opts.on("-b", "--board BOARD", "Issue board name (default: from config.json)") do |board|
      options[:board] = board
    end
    
    opts.on("-t", "--type TYPE", "Issue type (default: from config.json)",
            "Common types: Task, Story, Bug, Epic, Subtask") do |type|
      options[:type] = type
    end
    
    opts.on("-h", "--help", "Show this help") do
      log opts
      log ""
      log "Examples:"
      log "  issue \"Fix login bug\""
      log "  issue -b KRAFT \"Implement new feature\""
      log "  issue -t Bug \"Fix image display\""
      log "  issue -b BT -t Task \"User interface\""
      log ""
      log "Configuration:"
      log "  The command uses the config.json configuration file"
      log ""
      log "Supported board types:"
      log "  Scrum   - With sprints and backlog"
      log "  Kanban  - No sprints, continuous flow"
      log ""
      log "Sprint management:"
      log "  • Scrum boards: issue added to active sprint or backlog"
      log "  • Kanban boards: issue added directly to board"
      log "  • No active sprint: issue added to backlog"
      exit
    end
    
    opts.on("-v", "--version", "Show version") do
      log "Issue"
      exit
    end
  end.parse!

  title = ARGV[0]
  board_name = options[:board] || config.jira.default_board
  issue_type = options[:type] || config.jira.default_issue_type
  assignee_name = config.jira.assignee_name

  issue_client = JiraClient.build_from_config!(config)
  
  validate_create_issue_command!(title:, board_name:, issue_type:, assignee_name:)

  log "🚀 Creating Issue"
  log "Board: #{board_name}"
  log "Title: #{title}"
  log "Type: #{issue_type}"
  log "Assignee: #{assignee_name}"
  log ""
  
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

  if title.nil? || title.strip.empty?
    raise "Issue title is required"
  end
  
  if board_name.nil? || board_name.strip.empty?
    raise "Board name is required"
  end
  
  if issue_type.nil? || issue_type.strip.empty?
    raise "Issue type is required"
  end
  
  if assignee_name.nil? || assignee_name.strip.empty?
    raise "Assignee name is required"
  end
  
  log_success "Input parameters validated"
end