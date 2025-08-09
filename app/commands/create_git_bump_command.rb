def create_git_bump_command
  git_repo_client = GithubClient.build_from_config!(config)

  log "🚀 Creating Git Bump flow (Branche and Pull Request)"
  log ""

  create_git_bump_service = CreateGitBumpService.new(
    branch_name: "bump/#{DateTime.now.strftime('%Y-%m-%d')}",
    git_repo_client:,
    repo: github_repo_info[:repo],
    owner: github_repo_info[:owner],
    create_pull_request_service_factory: CreatePullRequestService
  )
  
  create_git_bump_service.call
end
