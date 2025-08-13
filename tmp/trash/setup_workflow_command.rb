module Commands
  class SetupWorkflowCommand < Command
    def call
      parse_options!

      branch_name = ARGV[0] || Features::Workflows::Git.current_branch
      issue = options[:issue]
      last_issue = Cache.get('last_issue.issue_key')

      if !branch_name && !issue && last_issue
        Prompt.yes_no(
          text: 'Do you want to use last issue created?',
          yes: proc {
            Log.info "issue set to '#{last_issue}'..."
            issue = last_issue
          }
        )
      end

      issue_client = Clients::JiraClient.build_from_config!
      git_repo_client = Clients::GithubClient.build_from_config!

      Log.log '🚀 Creating Git flow (Branche and Pull Request)'
      Log.log "Branch name: #{branch_name}"
      Log.log "Issue: #{issue}"
      Log.log ''

      Features::Workflows.setup_workflow(
        branch_name:,
        issue_key: issue,
        git_repo_client:,
        issue_client:
      ).call
    end

    def parse_options!
      OptionParser.new do |opts|
        opts.banner = 'Usage: [OPTIONS] "BRANCH_NAME"'
        opts.separator ''
        opts.separator 'Arguments:'
        opts.separator '  BRANCH_NAME  Branch name (optional, if not provided, ' \
                       'will use the current branch name unless issue is specified)'
        opts.separator ''
        opts.separator 'Options:'

        opts.on('-i', '--issue ISSUE', 'Issue (e.g., KRAFT-3735)') do |issue|
          options[:issue] = issue
        end

        opts.on('-h', '--help', 'Show this help') do
          Log.log opts
          Log.log ''
          Log.log 'Examples:'
          Log.log '  git-flow "Fix login bug"'
          Log.log '  git-flow -t KRAFT-3735'
          Log.log '  git-flow'
          Log.log ''
          Log.log 'Configuration:'
          Log.log '  The command uses the config.json configuration file'
          exit
        end

        opts.on('-v', '--version', 'Show version') do
          Log.log 'Git Flow'
          exit
        end
      end.parse!
    end
  end
end
