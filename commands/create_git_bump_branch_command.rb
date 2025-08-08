require_relative '../clients/jira_client'
require_relative '../clients/github_client'
require_relative '../services/create_git_bump_branch_service'

def create_git_bump_branch_command
  OptionParser.new do |opts|
    opts.on("-v", "--version", "Show version") do
      log "Git Bump"
      exit
    end
  end.parse!

  jira_client = JiraClient.build_from_config!(config)
  github_client = GithubClient.build_from_config!(config)

  create_git_bump_branch_service = CreateGitBumpBranchService.new(
    branch_name: "bump/#{DateTime.now.strftime('%Y-%m-%d')}",
    jira_ticket: nil, 
    jira_client:,
    github_client:
  )
  
  create_git_bump_branch_service.call
end
