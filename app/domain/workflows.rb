module Domain
  module Workflows
    extend self
    include Domain

    ### ACTIONS ###

    def setup_git_branch(**)
      Workflows::SetupGitBranchAction.call(**)
    end

    def setup_git_branch_from_issue(**)
      Workflows::SetupGitBranchFromIssueAction.call(**)
    end

    def setup_git_pull_request(**)
      Workflows::SetupGitPullRequestAction.call(**)
    end

    def create_issue(**)
      Workflows::CreateIssueAction.call(**)
    end

    def setup_note_from_git_branch(**)
      Workflows::SetupNoteFromGitBranchAction.call(**)
    end

    def setup_devflow(**)
      Workflows::SetupDevflowAction.call(**)
    end

    ### HELPERS ###

    def find_issue_for_branch(branch, issue_client)
      match = branch.match(/([A-Za-z]+)-(\d+)/)

      return nil unless match

      issue_key = "#{match[1]}-#{match[2]}"

      issue_client.fetch_issue(issue_key)
    end
  end
end
