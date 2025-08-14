module Commands
  class SetupGitBranchCommand
    include Command

    def call
      branch = ARGV[0]

      Domain::Workflows.setup_git_branch(branch:)
    end
  end
end
