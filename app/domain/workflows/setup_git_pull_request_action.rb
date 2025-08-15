module Domain
  module Workflows
    class SetupGitPullRequestAction
      include Action

      attr_reader(
        :git_repo_client,
        :issue_client
      )

      def call
        summary
        branch_protected!
        push_branch

        pull_request = existing_pull_request || create_pull_request
        url = pull_request['html_url']
        Open.browser(url)
        report(pull_request)

        url
      end

      private

      def summary
        Log.start 'Setup Pull Request'
      end

      def branch_protected!
        return unless Git.branch_protected?(branch)

        raise "Current branch '#{branch}' is protected. Please switch to another branch or create a new one."
      end

      def push_branch
        Git.push do
          Prompt.yes_no(
            text: 'Do you want to push --force-with-lease the branch?',
            yes: proc do
              Git.push(options: '--force-with-lease') do
                Prompt.yes_no(
                  text: 'Do you want to push --force the branch?',
                  yes: proc { Git.push(options: '--force') },
                  no: proc { true }
                )
              end
            end,
            no: proc { true }
          )
        end
      end

      memo def existing_pull_request
        pull_request = git_repo_client.fetch_pull_request_by_branch_name(
          owner, repo, branch
        )

        return pull_request if pull_request && pull_request['state'] == 'open'
        return nil unless pull_request

        Log.warn "Found existing Pull Request ##{pull_request['number']} (#{pull_request['state']})"
        Log.pad "Title: #{pull_request['title']}"
        Log.pad "URL: #{pull_request['html_url']}"

        Prompt.yes_no(
          text: "Continue and create a new Pull Request?",
          yes: proc {
            Log.info "Proceeding to create a new Pull Request..."
            pull_request = nil
          },
          no: proc do
            unless pull_request['state'] == 'closed' && !pull_request['merged']
              raise "Operation cancelled - no new Pull Request will be created"
            end

            Prompt.yes_no(
              text: "Would you like to reopen the existing PR instead?",
              yes: proc {
                pull_request = git_repo_client.reopen_pull_request(owner, repo, pull_request['number'])
              },
              no: proc { raise "Operation cancelled - no new Pull Request will be created" }
            )
          end
        )

        pull_request
      end

      def create_pull_request
        git_repo_client.create_pull_request(
          owner,
          repo,
          {
            title:,
            head: branch,
            base: base_branch,
            body:
          }
        )
      end

      def report(pull_request)
        Log.success(
          existing_pull_request ? "Pull Request already exists" : "Pull Request created successfully"
        )
        Log.pad "URL: #{pull_request['html_url']}"
        Log.pad "Title: #{pull_request['title']}"
        Log.pad "Number: #{pull_request['number']}"
      end

      ### STATE ###

      memo def branch
        Git.current_branch
      end

      memo def issue
        Workflows.find_issue_for_branch(branch, issue_client)
      end

      memo def title
        Git.formatted_branch_name(branch)
      end

      memo def description
        issue ? issue.description : title
      end

      memo def base_branch
        Git.base_branch.gsub(%r{^origin/}, '')
      end

      memo def repo_info
        Git.repo_info
      end

      memo def repo
        repo_info[:repo]
      end

      memo def owner
        repo_info[:owner]
      end

      memo def branch_type
        branch.split("/").first || "feat"
      end

      def body
        body = template

        body = if branch_type == 'fix'
                 body.gsub(/- \[ \] [Bb]ug/, '- [x] Bug fix')
               elsif branch_type == 'bump'
                 body.gsub(/- \[ \] .*?(gems|dependencies|dependency).*?$/, '- [x] Mise à jour de gems')
               else
                 body.gsub(/- \[ \] [Nn]ouvelle/, '- [x] Nouvelle fonctionnalité')
               end

        if issue
          body = body.gsub(
            /(##\s*📔?\s*[Tt]icket[^:\n]*:?)[\s-]*(?=[^\s-]|$)/mi,
            "\\1\n\n- [#{issue.key}](#{issue.url})\n\n"
          )
        end

        if description
          clean_description = description.gsub(/\{[^}]+\}/, '').strip
          body = body.gsub(
            /(##\s*📓?\s*[Dd]escription[^:\n]*:?)[\s-]*(?=[^\s-]|$)/mi,
            "\\1\n\n#{clean_description}\n\n"
          )
        end

        body
      end

      def template
        Log.info 'Fetching pull request template from local file...'

        template_path = File.join(Dir.pwd, 'pull_request_template.md')

        if File.exist?(template_path)
          Log.info "Found PR template at: #{template_path}"
          File.read(template_path)
        else
          Log.info "warn: Could not find PR template at #{template_path}, using default template"
          default_template
        end
      rescue StandardError => e
        Log.warn "Reading PR template file: #{e.message}"
        Log.log 'Using default template instead'
        default_template
      end

      def default_template
        default_template_path = File.join(APP_PATH, 'resources', 'default_pull_request_template.md')

        if File.exist?(default_template_path)
          Log.info "Using default template from: #{default_template_path}"
          File.read(default_template_path)
        else
          Log.warn "Default template not found at #{default_template_path}, using fallback template"
          fallback_template
        end
      rescue StandardError => e
        Log.warn "Reading default template file: #{e.message}"
        Log.log 'Using fallback template instead'
        fallback_template
      end

      def fallback_template
        <<~TEMPLATE
          ## Description

        TEMPLATE
      end
    end
  end
end
