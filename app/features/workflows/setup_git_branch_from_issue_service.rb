module Features
  module Workflows
    class SetupGitBranchFromIssueService < Service
      attr_reader(:issue_key, :issue_client, :issue)

      def call
        valid_attributes!
        summary
        find_issue
        Workflows.setup_git_branch(branch: branch_name)
        report

        branch_name
      end

      private

      def valid_attributes!
        if issue_key.nil? || issue_key.strip.empty?
          last_issue_created = Cache.get('last_issue_created')

          if last_issue_key
            Prompt.yes_no(
              text: "Issue key missing. Would you like to use the last created issue '#{last_issue_key}'?",
              yes: proc { @issue_key = last_issue_created["issue_key"] }
            )
          end
        end

        valid_attribute_or_ask(:issue_key, 'Issue key is required') { issue_key&.strip&.present? }
      end

      def summary
        Log.start("Setup Git branch from issue: #{issue_key}")
      end

      def find_issue
        @issue = issue_client.fetch_issue(issue_key) || raise("Issue with key '#{issue_key}' not found")
      end

      memo def branch_name
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
        Log.success "Branch '#{branch_name}' setup complete for issue #{issue_key}"
      end
    end
  end
end
