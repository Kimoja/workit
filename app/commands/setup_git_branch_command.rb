module Commands
  class SetupGitBranchCommand < Command
    def call
      branch = ARGV[0]

      raise "Branch name is required" if branch.nil? || branch.empty?

      Features::Workflows.setup_git_branch(branch:)
    end
  end
end
