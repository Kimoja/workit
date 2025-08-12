module Features
  module Workflows
    class SetupGitBranchFromIssueService < Service
      attr_reader(:issue_key, :issue_client)

      def call
        summary
        valid_attributes!
        issue = find_issue
        Workflows.setup_git_branch(branch: branch_name_for_issue(issue))
        report
      end

      private

      def summary
        Log.start("Setup Git branch from issue: #{issue_key}")
      end

      def valid_attributes!
        raise "Issue key is required" if issue_key.nil? || issue_key.empty?
      end

      def find_issue
        issue_client.fetch_issue(issue_key) || raise("Issue with key '#{issue_key}' not found")
      end

      def branch_name_for_issue(issue)
        # FIXME: This is a temporary solution, should be moved to a config file
        prefix = issue.issue_type == 'bug' ? 'fix/' : 'feat/'
        branch_suffix = issue.title
                             .downcase
                             .gsub(/^\[.*?\]\s*/, '')
                             .gsub(/\s+/, '-')
                             .gsub(/-+/, '-')
                             .gsub(/^-|-$/, '')

        "#{prefix}#{issue_key}-#{branch_suffix}"
      end

      def report
        Log.success "Branch from issue '#{issue_key}' created successfully"
      end
    end
  end
end
