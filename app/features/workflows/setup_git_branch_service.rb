module Features
  module Workflows
    class SetupGitBranchService < Service
      attr_reader(:branch)

      def call
        Log.log("🚀 Setup Git branch: #{branch}")

        Git.navigate_to_repo

        if branch == Git.current_branch
          Log.info("Already on branch '#{branch}'")
          return commit_uncommited_changes!
        end

        stash_uncommited_changes

        return checkout_to_existing_branch if Git.branch_exists?(branch)

        checkout_to_base_branch
        Git.create_branch(branch)
        Git.commit(commit_message, '--allow-empty')
      end

      private

      def commit_uncommited_changes
        return unless Git.changes?

        Log.warn "Changes detected on branch: '#{current_branch}'"

        Git.commit("Autocommit branch: #{branch}")
      end

      def stash_uncommited_changes
        return unless Git.changes?

        Log.warn "Changes detected on branch: '#{Git.current_branch}'"

        Git.stash_changes
      end

      def checkout_to_existing_branch
        Log.info "Branch '#{branch}' already exists"

        Git.checkout(branch)

        Git.pull do
          Prompt.yes_no(
            text: 'Do you want to continue without pulling the branch?',
            yes: proc { Git.changes? ? Git.abort_rebase : true },
            no: proc { false }
          )
        end
      end

      def checkout_to_base_branch
        main_branch = Git.main_branch
        current_branch = Git.current_branch

        return Git.pull if main_branch == current_branch

        Prompt.yes_no(
          text: "Do you want to use '#{main_branch}' as base branch or use the current branch " \
                "'#{current_branch}'? (y for #{main_branch}, n for current)",
          yes: proc {
            Git.checkout(main_branch)
          },
          no: proc {
            Log.info "Using current branch '#{current_branch}' as base branch..."
          }
        )

        Git.pull do
          Prompt.yes_no(
            text: 'Do you want to continue without pulling the base branch?',
            yes: proc { Git.changes? ? Git.abort_rebase : true },
            no: proc { false }
          )
        end
      end

      def commit_message
        Branch.commit_message_from_branch(branch)
      end
    end
  end
end
