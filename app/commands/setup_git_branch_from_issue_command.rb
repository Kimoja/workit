module Commands
  class SetupGitBranchFromIssueCommand < Command
    def call
      issue_key = ARGV[0]

      raise "Issue key is required" if issue_key.nil? || issue_key.empty?

      issue_client = Clients::JiraClient.build_from_config!

      Features::Workflows.setup_git_branch_from_issue(issue_key:, issue_client:)
    end
  end
end
