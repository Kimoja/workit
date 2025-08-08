require_relative '../clients/github_client'
require_relative '../services/create_git_bump_service'

def create_git_bump_command
  OptionParser.new do |opts|
    opts.on("-v", "--version", "Show version") do
      log "Git Bump"
      exit
    end
  end.parse!

  github_client = GithubClient.build_from_config!(config)

  create_git_bump_service = CreateGitBumpService.new(
    branch_name: "bump/#{DateTime.now.strftime('%Y-%m-%d')}",
    github_client:
  )
  
  create_git_bump_service.call
end
