module Commands
  module Workflows
    class SetupGitBranchFromIssueCommand
      include Command

      self.function = "setup-git-branch-issue"
      self.aliases = ["branch-issue"]
      self.summary = "Setup development branch from issue tracker for new work"

      def call
        options = parse_options

        issue_key = ARGV[0]
        base_branch = options[:base_branch]
        issue_client = Clients::Issues.build_from_config!

        Domain::Workflows.setup_git_branch_from_issue(
          issue_key:,
          base_branch:,
          issue_client:
        )
      end

      private

      def parse_options
        options = {
          base_branch: nil
        }

        OptionParser.new do |opts|
          opts.banner = "Usage: #{self.class.summary} [OPTIONS] [ISSUE_KEY]\n\n#{self.class.summary}"
          opts.separator ''
          opts.separator 'Arguments:'
          opts.separator '  ISSUE_KEY  Key of the issue (optional, will prompt if not provided)'
          opts.separator ''
          opts.separator 'Options:'

          opts.on('-b', '--base-branch BASE_BRANCH',
                  'Base branch to create from (default: auto-detect main/master)',
                  'Examples: main, develop, feature/parent-branch') do |base_branch|
            options[:base_branch] = base_branch
          end

          opts.on('-h', '--help', 'Show this help') do
            show_help(opts)
            exit
          end
        end.parse!

        options
      end

      def show_help(opts)
        Log.log opts
        Log.log ''
        Log.log 'Examples:'
        Log.log "  #{self.class.summary} PROJ-123"
        Log.log "  #{self.class.summary} -b develop PROJ-456"
        Log.log "  #{self.class.summary}  # Will prompt for issue selection"
        Log.log ''
        Log.log 'Behavior:'
        Log.log '  • Fetches issue details from your issue tracker'
        Log.log '  • Generates branch name from issue type and title'
        Log.log '  • Creates and switches to the new branch'
        Log.log ''
        Log.log 'Branch naming:'
        Log.log '  • Bug issues: fix/ISSUE-123-description'
        Log.log '  • Feature issues: feat/ISSUE-123-description'
      end
    end
  end
end
