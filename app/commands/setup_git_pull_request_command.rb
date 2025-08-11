module Commands
  class SetupGitPullRequestCommand < Command
    def call
      git_repo_client = Clients::GithubClient.build_from_config!
      issue_client = Clients::JiraClient.build_from_config!

      Features::Workflows.setup_git_pull_request(git_repo_client:, issue_client:)
    end
  end
end
