module Commands
  class SetupNoteFromGitBranchCommand
    include Command

    def call
      parse_options

      issue_client = Clients::Issues.build_from_config!

      Domain::Workflows.setup_note_from_git_branch(
        issue_client: issue_client
      )
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: setup-note-git-branch"
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
      Log.log '  setup-note-from-git-branch'
      Log.log '  note  # Alternative command name alias'
      Log.log ''
      Log.log 'Behavior:'
      Log.log '  • Setup a work note document from current git branch'
      Log.log '  • Automatically detects branch name and related issue'
      Log.log '  • Generates note template with branch context'
      Log.log '  • Saves to .workspace/notes/ directory'
      Log.log ''
      Log.log 'Generated content:'
      Log.log '  • Related issue details (if found)'
      Log.log ''
      Log.log 'File location:'
      Log.log '  • .workspace/notes/YYYY-MM-DD_branch-name_notes.md'
      Log.log '  • Automatically opens in default editor'
      Log.log ''
      Log.log 'Integration:'
      Log.log '  • Links to issues if branch follows naming convention'
    end
  end
end
