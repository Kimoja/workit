module Domain
  module Workflows
    class SetupGitBranchAction
      include Action

      attr_reader(:branch, :base_branch)

      def call
        valid_attributes!
        summary

        Git.navigate_to_repo
        return if branch_is_current_branch?

        stash_uncommited_changes
        return if checkout_to_existing_branch?

        checkout_to_base_branch
        Git.create_branch(branch)
        Git.commit(commit_message, '--allow-empty')

        report
      end

      private

      def summary
        Log.start("Setup Git branch: #{branch}")
        Log.pad("- Branch name: #{branch}")
      end

      def valid_attributes!
        valid_attribute_or_ask(
          attribute: :branch,
          text: 'Branch name is required'
        ) { branch&.strip&.present? }

        valid_attribute_or_select(
          attribute: :base_branch,
          text: 'Select base branch for the new branch:',
          options: Git.recent_branches,
          default: Git.main_branch
        ) { base_branch&.strip&.present? }
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

      def checkout_to_base_branch
        Git.checkout(main_branch) unless base_branch == Git.current_branch

        pull_if_remote('Do you want to continue without pulling the base branch?')
      end

      def pull_if_remote(text)
        return unless Git.remote_branch_exists?(Git.current_branch)

        Git.pull do
          Prompt.yes_no(
            text:,
            yes: proc { Git.changes? ? Git.abort_rebase : true },
            no: proc { false }
          )
        end
      end

      def commit_message
        Git.commit_message_from_branch(branch)
      end

      def report
        Log.success "Switched to new branch '#{branch}'"
      end
    end
  end
end
