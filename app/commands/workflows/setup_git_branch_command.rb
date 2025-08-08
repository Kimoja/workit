module Commands
  module Workflows
    class SetupGitBranchCommand
      include Command

      self.function = "setup-git-branch"
      self.aliases = ["branch"]
      self.summary = "Setup development branch for new work"

      def call
        options = parse_options

        branch = ARGV[0]
        base_branch = options[:base_branch]

        Domain::Workflows.setup_git_branch(
          branch: branch,
          base_branch: base_branch
        )
      end

      private

      def parse_options
        options = {
          base_branch: nil
        }

        OptionParser.new do |opts|
          opts.banner = "Usage: #{self.class.summary} [OPTIONS] BRANCH_NAME\n\n#{self.class.summary}"
          opts.separator ''
          opts.separator 'Arguments:'
          opts.separator '  BRANCH_NAME  Name of the branch to create/switch to (required)'
          opts.separator ''
          opts.separator 'Options:'

          opts.on('-b', '--base-branch BASE_BRANCH',
                  'Base branch to create from (default: auto-detect main/master)') do |base_branch|
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
        Log.log "  #{self.class.summary} feature/new-ui"
        Log.log "  #{self.class.summary} -b develop feature/user-auth"
        Log.log "  #{self.class.summary} -b main bugfix/login-error"
        Log.log ''
        Log.log 'Behavior:'
        Log.log '  • If branch exists locally: switch to it'
        Log.log '  • If branch exists on remote: fetch and switch'
        Log.log '  • If branch doesn\'t exist: create from base branch'
        Log.log ''
        Log.log 'Configuration:'
        Log.log '  • Default base branch can be set in config.json'
      end
    end
  end
end
