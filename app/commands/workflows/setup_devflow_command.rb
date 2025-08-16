module Commands
  module Workflows
    class SetupDevflowCommand
      include Command

      self.function = "setup-devflow"
      self.aliases = ["devflow"]
      self.summary = "Interactive development workflow (issue → branch → notes → PR)"

      def call
        parse_options

        issue_client = Clients::Issues.build_from_config!
        git_repo_client = Clients::GitRepositories.build_from_config!

        Domain::Workflows.setup_devflow(
          issue_client:,
          git_repo_client:
        )
      end

      private

      def parse_options
        OptionParser.new do |opts|
          opts.banner = "Usage: #{self.class.function}\n\n#{self.class.summary}"
          opts.separator ''

          opts.on('-h', '--help', 'Show this help') do
            show_help(opts)
            exit
          end
        end.parse!

        {}
      end

      def show_help(opts)
        Log.log opts
        Log.log ''
        Log.log 'Usage Examples:'
        Log.log "  #{self.class.function}  # Start interactive dev workflow"
        Log.log "  flow                    # Quick alias"
        Log.log ''
        Log.log 'Dev workflow Scenarios:'
        Log.log ''
        Log.log '  New Feature Development:'
        Log.log '    1. Create new issue → Auto branch → Notes → PR'
        Log.log ''
        Log.log '  Existing Issue Work:'
        Log.log '    1. Select issue → Auto branch from issue → Notes → PR'
        Log.log ''
        Log.log '  Quick Fix/Experiment:'
        Log.log '    1. Skip issue → Manual branch → Optional notes'
        Log.log ''
        Log.log 'Interactive Prompts:'
        Log.log '  • Issue handling (create/select/skip)'
        Log.log '  • Branch creation confirmation'
        Log.log '  • Work notes setup (yes/no)'
        Log.log '  • Pull request creation (yes/no)'
        Log.log ''
        Log.log 'Integration:'
        Log.log '  • Jira issues ↔ Git branches ↔ GitHub PRs'
        Log.log '  • Automatic sprint assignment'
        Log.log '  • Structured work documentation'
      end
    end
  end
end
