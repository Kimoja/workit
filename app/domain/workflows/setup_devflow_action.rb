module Domain
  module Workflows
    class SetupDevflowAction
      include Action

      def call
        summary

        issue_workflow = select_issue_workflow
        branch =
          case issue_workflow
          when :create_new_issue_workflow
            issue = create_new_issue
            setup_branch_issue(issue:)
          when :existing_issue_workflow
            setup_branch_issue
          when :branch_only_workflow
            setup_branch
          end
        setup_work_notes
        setup_pull_request_if_wanted

        report(issue, branch)
      end

      private

      attr_reader :issue_client, :git_repo_client

      def summary
        Log.start "Complete Development Workflow"
        Log.pad "This will guide you through the full development process"
        Log.log ""
      end

      def select_issue_workflow
        Prompt.select(
          "What would you like to do?",
          [
            "Create new issue → branch",
            "Use existing issue → branch",
            "Create branch only (no issue)",
            "Cancel"
          ],
          default: "Use existing issue → branch"
        ) do |choice|
          case choice
          when "Create new issue → branch"
            :create_new_issue_workflow
          when "Use existing issue → branch"
            :existing_issue_workflow
          when "Create branch only (no issue)"
            :branch_only_workflow
          when "Cancel"
            raise "Workflow cancelled"
          end
        end
      end

      def create_new_issue
        Domain::Workflows.create_issue(issue_client:)
      end

      def setup_branch_issue(issue: nil)
        Domain::Workflows.setup_git_branch_from_issue(issue:, issue_client:)
      end

      def setup_branch
        Domain::Workflows.setup_git_branch
      end

      def setup_work_notes
        Prompt.yes_no(
          "Create work notes for this development?",
          yes: proc {
            Domain::Workflows.setup_note_from_git_branch(
              issue_client: issue_client
            )
          },
          no: proc {
            Log.info "You can create the note document later with: note"
          }
        )
      end

      def setup_pull_request_if_wanted
        Prompt.yes_no(
          "Create pull request now?",
          yes: proc {
            Domain::Workflows.setup_git_pull_request(
              git_repo_client: git_repo_client,
              issue_client: issue_client
            )
          },
          no: proc {
            Log.info "You can create the PR later with: pr"
          }
        )
      end

      def report
        Log.success "Development workflow setup complete!"
      end
    end
  end
end
