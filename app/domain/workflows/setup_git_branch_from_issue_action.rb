module Domain
  module Workflows
    class SetupGitBranchFromIssueAction
      include Action

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
        valid_attribute_or_select(
          attribute: :issue_key,
          text: 'Issue key is required',
          options: proc do 
            fetch_user_issues
              .fetch_user_issue_keys(Config.get("@issue_provider", "default_assignee_name")) 
              .map do |issue| 
                "#{ issue.key } > #{ issue.title }"
              end
          end
        ) { issue_key&.strip&.present? }
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
                             .gsub(/['"]/, '')

        "#{prefix}#{issue_key}-#{branch_suffix}"
      end

      def report
        Log.success "Branch '#{branch_name}' setup complete for issue #{issue_key}"
      end
    end
  end
end
