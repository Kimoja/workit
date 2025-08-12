module Commands
  class SetupGitBranchCommand < Command
    def call
      branch = ARGV[0]

      Features::Workflows.setup_git_branch(branch:)
    end
  end
end
