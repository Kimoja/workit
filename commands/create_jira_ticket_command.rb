require_relative '../clients/jira_client'
require_relative '../services/create_jira_ticket_service'

def create_jira_ticket_command
  options = {
    board: nil,
    type: nil
  }
  
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS] \"TICKET_TITLE\""
    opts.separator ""
    opts.separator "Arguments:"
    opts.separator "  TICKET_TITLE  Title of the ticket to create (required)"
    opts.separator ""
    opts.separator "Options:"
    
    opts.on("-b", "--board BOARD", "Jira board name (default: from config.json)") do |board|
      options[:board] = board
    end
    
    opts.on("-t", "--type TYPE", "Jira issue type (default: from config.json)",
            "Common types: Task, Story, Bug, Epic, Subtask") do |type|
      options[:type] = type
    end
    
    opts.on("-h", "--help", "Show this help") do
      log opts
      log ""
      log "Examples:"
      log "  jira-ticket \"Fix login bug\""
      log "  ticket -b KRAFT \"Implement new feature\""
      log "  ticket -t Bug \"Fix image display\""
      log "  ticket -b BT -t Task \"User interface\""
      log ""
      log "Configuration:"
      log "  The command uses the config.json configuration file"
      log ""
      log "Supported board types:"
      log "  Scrum   - With sprints and backlog"
      log "  Kanban  - No sprints, continuous flow"
      log ""
      log "Sprint management:"
      log "  • Scrum boards: ticket added to active sprint or backlog"
      log "  • Kanban boards: ticket added directly to board"
      log "  • No active sprint: ticket added to backlog"
      exit
    end
    
    opts.on("-v", "--version", "Show version") do
      log "Jira Ticket"
      exit
    end
  end.parse!

  title = ARGV[0]
  board_name = options[:board] || config.jira.default_board
  issue_type = options[:type] || config.jira.default_issue_type
  assignee_name = config.jira.assignee_name
  jira_url = config.jira.url

  jira_client = JiraClient.build_from_config!(config)
  
  validate_create_jira_ticket_command!(title:, board_name:, issue_type:, assignee_name:, jira_url:, jira_client:)

  create_jira_ticket_service = CreateJiraTicketService.new(
    title:,
    board_name:,
    issue_type:,
    assignee_name:,
    jira_url:,
    jira_client:
  )
  
  create_jira_ticket_service.call
end

def validate_create_jira_ticket_command!(title:, board_name:, issue_type:, assignee_name:, jira_url:, jira_client:)

  if title.nil? || title.strip.empty?
    log_error "Ticket title is required"
    exit 1
  end
  
  if board_name.nil? || board_name.strip.empty?
    log_error "Board name is required"
    exit 1
  end
  
  if issue_type.nil? || issue_type.strip.empty?
    log_error "Issue type is required"
    exit 1
  end
  
  if assignee_name.nil? || assignee_name.strip.empty?
    log_error "Assignee name is required"
    exit 1
  end
  
  if jira_url.nil? || jira_url.strip.empty?
    log_error "Jira URL is required"
    exit 1
  end
  
  unless jira_url.match?(/\Ahttps?:\/\/.+\.atlassian\.net\z/)
    log_warning "Warning: Jira URL doesn't appear to be a standard Atlassian URL"
    log "Configured URL: #{jira_url}"
  end

  log_success "Input parameters validated"
end