module Features
  module Workflows
    extend self
    include Utils

    def setup_git_branch(...)
      Workflows::SetupGitBranchService.call(...)
    end

    def setup_git_branch_from_issue(...)
      Workflows::SetupGitBranchFromIssueService.call(...)
    end

    def setup_git_pull_request(...)
      Workflows::SetupGitPullRequestService.call(...)
    end

    #--

    def setup_workflow(...)
      Workflows::SetupWorkflowService.call(...)
    end

    def create_pull_request(...)
      Workflows::CreatePullRequestService.call(...)
    end

    def get_existing_pull_request(provider:, owner:, repo:, branch_name:, git_repo_client:)
      cached_pr = Cache.get("prs", provider, owner, repo, branch_name)
      return cached_pr if cached_pr

      git_repo_client.fetch_pull_request_by_branch_name(owner, repo, branch_name)
    end
  end
end
