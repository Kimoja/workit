module Functions
  module Workflows
    class SetupGitBranchAction
      include Action

      def call
        setup_and_valid_branch!
        summary

        return branch if branch_is_current_branch?

        stash_uncommited_changes
        return branch if checkout_to_existing_branch?

        setup_and_valid_base_branch!

        checkout_to_base_branch
        Git.create_branch(branch)
        Git.commit(commit_message, options: '--allow-empty')

        report

        branch
      end

      attr_reader(:branch, :base_branch)

      private

      def setup_and_valid_branch!
        valid_attribute_or_ask(:branch, 'Branch name is required') { branch&.strip&.present? }
      end

      def summary
        Log.start("Setup Git branch: #{branch}")
        Log.pad("- Branch name: #{branch}")
      end

      def branch_is_current_branch?
        return false unless branch == Git.current_branch

        Log.success("Already on branch '#{branch}'")
        true
      end

      def stash_uncommited_changes
        return unless Git.changes?

        Log.warn "Changes detected on branch: '#{Git.current_branch}'"

        Git.stash_changes
      end

      def checkout_to_existing_branch?
        return false unless Git.branch_exists?(branch)

        Log.info "Branch '#{branch}' already exists"
        Git.checkout(branch)
        pull_if_remote('Do you want to continue without pulling the branch?')
        Log.success("Switched to branch '#{branch}'")

        true
      end

      def setup_and_valid_base_branch!
        valid_attribute_or_select(
          :base_branch,
          'Select base branch for the new branch:',
          proc { Git.recent_branches },
          default: proc { Git.main_branch }
        ) { base_branch&.strip&.present? }
      end

      def recent_branches
        Log.start("Setup Git branch: #{branch}")
        Log.pad("- Branch name: #{branch}")
      end

      def checkout_to_base_branch
        Git.checkout(base_branch) unless base_branch == Git.current_branch

        pull_if_remote('Do you want to continue without pulling the base branch?')
      end

      def pull_if_remote(text)
        return unless Git.remote_branch_exists?(Git.current_branch)

        Git.pull do
          Prompt.confirm(
            text,
            yes: proc { Git.changes? ? Git.abort_rebase : true },
            no: proc { false }
          )
        end
      end

      def commit_message
        Git.formatted_branch_name(branch)
      end

      def report
        Log.success "Switched to new branch '#{branch}'"
      end
    end
  end
end
