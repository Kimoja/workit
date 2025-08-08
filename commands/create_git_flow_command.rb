require_relative '../clients/jira_client'
require_relative '../clients/github_client'
require_relative '../services/create_git_flow_service'

def create_git_flow_command
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: [OPTIONS] \"BRANCH_NAME\""
    opts.separator ""
    opts.separator "Arguments:"
    opts.separator "  BRANCH_NAME  Branch name (optional if --jira-ticket is defined)"
    opts.separator ""
    opts.separator "Options:"
    
    opts.on('-t', '--jira-ticket TICKET', 'Jira ticket (e.g., KRAFT-3735)') do |ticket|
      options[:jira_ticket] = ticket
    end
    
    opts.on("-h", "--help", "Show this help") do
      log opts
      log ""
      log "Examples:"
      log "  git-branch \"Fix login bug\""
      log "  branch -t KRAFT-3735"
      log ""
      log "Configuration:"
      log "  The command uses the config.json configuration file"
      exit
    end
    
    opts.on("-v", "--version", "Show version") do
      log "Jira Ticket (Cache with string keys)"
      exit
    end
  end.parse!

  branch_name = ARGV[0]
  jira_ticket = options[:jira_ticket]
  last_jira_ticket = cache_get("last_jira_ticket")&.fetch("issue_key")

  if !branch_name && !jira_ticket && last_jira_ticket
    yes_no(
      text: "Do you want to use last Jira create ticket?", 
      yes: proc {
        log "jira_ticket set to '#{last_jira_ticket}'..."
        jira_ticket = last_jira_ticket
      }
    )
  end

  jira_client = JiraClient.build_from_config!(config)
  github_client = GithubClient.build_from_config!(config)

  validate_git_flow_command_inputs!(branch_name:, jira_ticket:)

  create_git_flow_service = CreateGitFlowService.new(
    branch_name:,
    jira_ticket:, 
    jira_client:,
    github_client:
  )
  
  create_git_flow_service.call
end

def validate_git_flow_command_inputs!(branch_name:, jira_ticket:)
  if (branch_name.nil? || branch_name.strip.empty?) && (jira_ticket.nil? || jira_ticket.strip.empty?)
    log_error "Branch name or Jira ticket is required"
    exit 1
  end

  log_success "Input parameters validated"
end