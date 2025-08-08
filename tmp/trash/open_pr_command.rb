module Commands
  class OpenPrCommand
    def call
      git_repo_client = GithubClient.build_from_config!(config)

      Log.log '🚀 Open PR from current branch'

      Domain::Workflows::Git.navigate_to_repo

      repo = github_repo_info[:repo]
      owner = github_repo_info[:owner]
      branch_name = Domain::Workflows::Git.current_branch

      pr = Cache.get("pr_#{repo}_#{branch_name}") || git_repo_client.fetch_pull_request_by_branch_name(owner, repo,
                                                                                                       branch_name)

      raise "No open pull request found for branch '#{branch_name}'" unless pr

      Open.browser(pr['url'])
    end
  end
end
