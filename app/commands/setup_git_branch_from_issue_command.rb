module Commands
  class SetupGitBranchFromIssueCommand
    include Command

    def call
      issue_key = ARGV[0]
      issue_client = Clients::JiraClient.build_from_config!

      Domain::Workflows.setup_git_branch_from_issue(issue_key:, issue_client:)
    end
  end
end
