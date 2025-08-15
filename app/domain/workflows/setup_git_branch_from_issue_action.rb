module Domain
  module Workflows
    class SetupGitBranchFromIssueAction
      include Action

      def call
        setup_and_valid_attributes!
        summary
        find_issue
        Workflows.setup_git_branch(branch:)
        report

        branch
      end

      private

      attr_reader(:issue_client, :issue)

      def setup_and_valid_attributes!
        valid_attribute_or_select(
          :issue_key,
          'Issue key is required',
          proc { possible_issue_keys },
          formatter: proc { |value| value.split(' > ').first }
        ) { issue_key&.strip&.present? }
      end

      def possible_issue_keys
        issue_client
          .fetch_user_issues(Config.get("@issue_provider", "default_user_name"))
          .map { |issue| "#{issue.key} > #{issue.title}" }
      end

      def summary
        Log.start("Setup Git branch from issue: #{issue_key}")
      end

      def issue_key
        @issue_key || issue&.key
      end

      def find_issue
        return issue if defined?(@issue) && @issue

        @issue = issue_client.fetch_issue(issue_key) || raise("Issue with key '#{issue_key}' not found")
      end

      memo def branch
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
        Log.success "Branch '#{branch}' setup complete for issue #{issue_key}"
      end
    end
  end
end
