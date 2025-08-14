module Domain
  module Workflows
    extend self
    include Domain

    def setup_git_branch(...)
      Workflows::SetupGitBranchAction.call(...)
    end

    def setup_git_branch_from_issue(...)
      Workflows::SetupGitBranchFromIssueAction.call(...)
    end

    def setup_git_pull_request(...)
      Workflows::SetupGitPullRequestAction.call(...)
    end

    def create_issue(...)
      Workflows::CreateIssueAction.call(...)
    end

    #--

    def setup_workflow(...)
      Workflows::SetupWorkflowAction.call(...)
    end

    def create_pull_request(...)
      Workflows::CreatePullRequestAction.call(...)
    end

    def get_existing_pull_request(provider:, owner:, repo:, branch_name:, git_repo_client:)
      cached_pr = Cache.get("prs", provider, owner, repo, branch_name)
      return cached_pr if cached_pr

      git_repo_client.fetch_pull_request_by_branch_name(owner, repo, branch_name)
    end
  end
end
