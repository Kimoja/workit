module Commands
  module Workflows
    class SetupGitPullRequestCommand
      include Command

      def call
        parse_options

        git_repo_client = Clients::GitRepositories.build_from_config!
        issue_client = Clients::Issues.build_from_config!

        Domain::Workflows.setup_git_pull_request(
          git_repo_client: git_repo_client,
          issue_client: issue_client
        )
      end

      private

      def parse_options
        OptionParser.new do |opts|
          opts.banner = "Usage: pr"
          opts.separator ''

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
        Log.log '  setup_pull_request'
        Log.log ''
        Log.log 'Behavior:'
        Log.log '  • Creates or updates a pull request from current/specified branch'
        Log.log '  • Links to related issues if found'
        Log.log '  • Opens the pull request in browser'
        Log.log ''
        Log.log 'Integration:'
        Log.log '  • Links GitHub PR with Jira issues automatically'
      end
    end
  end
end
