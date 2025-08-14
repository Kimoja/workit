module Commands
  class CreateGitBumpCommand
    def call
      git_repo_client = GithubClient.build_from_config!(config)

      Log.log '🚀 Creating Git Bump flow (Branche and Pull Request)'
      Log.log ''

      create_git_bump_service = CreateGitBumpAction.new(
        branch_name: "bump/#{DateTime.now.strftime('%Y-%m-%d')}",
        git_repo_client:,
        repo: github_repo_info[:repo],
        owner: github_repo_info[:owner],
        create_pull_request_service_factory: CreatePullRequestAction
      )

      create_git_bump_service.call
    end
  end
end
