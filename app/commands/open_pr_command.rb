def open_pr_command
  git_repo_client = GithubClient.build_from_config!(config)

  log "🚀 Open PR from current branch"

  git_navigate_to_repo!
  
  repo = github_repo_info[:repo]
  owner = github_repo_info[:owner]
  branch_name = git_current_branch

  pr = cache_get("pr_#{repo}_#{branch_name}") || git_repo_client.fetch_pull_request_by_branch_name(owner, repo, branch_name)

  raise "No open pull request found for branch '#{branch_name}'" unless pr
  
  open_browser(pr["url"])
end
