def create_git_flow_command
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: [OPTIONS] \"BRANCH_NAME\""
    opts.separator ""
    opts.separator "Arguments:"
    opts.separator "  BRANCH_NAME  Branch name (optional, if not provided, will use the current branch name unless issue is specified)"
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
      log "  git-flow"
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

  branch_name = ARGV[0] || git_current_branch
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
  git_repo_client = GithubClient.build_from_config!(config)

  log "🚀 Creating Git flow (Branche and Pull Request)"
  log "Branch name: #{branch_name}"
  log "Issue: #{issue}"
  log ""

  create_git_flow_service = Workflows.create_git_flow(
    branch_name:,
    issue_key: issue, 
    git_repo_client:,
    repo: github_repo_info[:repo],
    owner: github_repo_info[:owner],
    issue_client:,
    create_pull_request_service_factory: CreatePullRequestService
  )

  create_git_flow_service.call
end
