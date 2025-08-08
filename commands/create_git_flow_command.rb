require_relative '../clients/jira_client'
require_relative '../clients/github_client'
require_relative '../services/create_git_flow_service'

def create_git_flow_command
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: [OPTIONS] \"BRANCH_NAME\""
    opts.separator ""
    opts.separator "Arguments:"
    opts.separator "  BRANCH_NAME  Branch name (optional if --issue is defined)"
    opts.separator ""
    opts.separator "Options:"
    
    opts.on('-i', '--issue ISSUE', 'Issue (e.g., KRAFT-3735)') do |issue|
      options[:issue] = issue
    end
    
    opts.on("-h", "--help", "Show this help") do
      log opts
      log ""
      log "Examples:"
      log "  git-flow \"Fix login bug\""
      log "  git-flow -t KRAFT-3735"
      log ""
      log "Configuration:"
      log "  The command uses the config.json configuration file"
      exit
    end
    
    opts.on("-v", "--version", "Show version") do
      log "Git Flow"
      exit
    end
  end.parse!

  branch_name = ARGV[0]
  issue = options[:issue]
  last_issue = cache_get("last_issue")&.fetch("issue_key")

  if !branch_name && !issue && last_issue
    yes_no(
      text: "Do you want to use last issue created?", 
      yes: proc {
        log "issue set to '#{last_issue}'..."
        issue = last_issue
      }
    )
  end

  issue_client = JiraClient.build_from_config!(config)
  github_client = GithubClient.build_from_config!(config)

  validate_git_flow_command_inputs!(branch_name:, issue:)

  log "🚀 Creating Git flow (Branche and Pull Request)"
  log "Branch name: #{branch_name}"
  log "Issue: #{issue}"
  log ""

  create_git_flow_service = CreateGitFlowService.new(
    branch_name:,
    issue_key: issue, 
    issue_client:,
    github_client:,
  )

  create_git_flow_service.call
end

def validate_git_flow_command_inputs!(branch_name:, issue:)
  if (branch_name.nil? || branch_name.strip.empty?) && (issue.nil? || issue.strip.empty?)
    log_error "Branch name or Issue is required"
    exit 1
  end

  log_success "Input parameters validated"
end