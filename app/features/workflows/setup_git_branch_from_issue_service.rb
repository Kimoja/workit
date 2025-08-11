module Features
  module Workflows
    class SetupGitBranchFromIssueService < Service
      attr_reader(:issue_key, :issue_client)

      def call
        Log.log("🚀 Setup Git branch from issue: #{issue_key}")

        Workflows.setup_git_branch(branch_name:)
      end

      private

      def issue
        @issue ||= issue_client.fetch_issue(issue_key) || raise("Issue with key '#{issue_key}' not found")
      end

      def branch_name
        @branch_name ||= begin
          prefix = issue.issue_type == 'bug' ? 'fix/' : 'feat/'
          branch_suffix = issue.title
                               .downcase
                               .gsub(/^\[.*?\]\s*/, '')
                               .gsub(/\s+/, '-')
                               .gsub(/-+/, '-')
                               .gsub(/^-|-$/, '')

          "#{prefix}#{issue_key}-#{branch_suffix}"
        end
      end
    end
  end
end
