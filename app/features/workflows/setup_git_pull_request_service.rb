module Features
  module Workflows
    class SetupGitPullRequestService < Service
      attr_reader(
        :git_repo_client,
        :issue_client
      )

      def call
        Git.navigate_to_repo

        Log.log("🚀 Setup Pull Request for branch: #{branch}")

        branch_protected!
        push_branch
        pull_request = create_pull_request
        add_to_cache(pull_request)

        report
      end

      private

      def branch
        @branch ||= Git.current_branch
      end

      def issue
        return @issue if defined?(@issue)

        @issue = find_issue
      end

      def title
        @title ||= Branch.commit_message_from_branch(branch)
      end

      def description
        @description ||= issue ? issue.description : title
      end

      def base_branch
        @base_branch ||= Git.base_branch.gsub(%r{^origin/}, '')
      end

      def repo_info
        @repo_info ||= Git.repo_info
      end

      def find_issue
        match = branch.match(/([A-Za-z]+)-(\d+)/)

        return nil unless match

        issue_key = "#{match[1]}-#{match[2]}"

        issue_client.fetch_issue(issue_key)
      end

      def branch_type
        @branch_type ||= branch.split("/").first || "feat"
      end

      def branch_protected!
        return unless Git.branch_protected?(branch)

        raise "Current branch '#{branch}' is protected. Please switch to another branch or create a new one."
      end

      def push_branch
        Git.push_force_with_lease do
          Prompt.yes_no(
            text: 'Do you want to push --force the branch?',
            yes: proc { Git.push_force },
            no: proc { false }
          )
        end
      end

      def create_pull_request
        git_repo_client.create_pull_request(
          repo_info[:owner],
          repo_info[:repo],
          {
            title:,
            head: branch,
            base: base_branch,
            body:
          }
        )
      end

      def add_to_cache(pull_request)
        Cache.set(
          "prs", repo_info[:repo], branch,
          value: {
            url: pull_request['html_url'],
            number: pull_request['number'],
            title: pull_request['title']
          }
        )
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

      def report(pull_request)
        Log.success "Pull Request created successfully"
        Log.pad "URL: #{pull_request['html_url']}"
        Log.pad "Title: #{pull_request['title']}"
        Log.pad "Number: #{pull_request['number']}"
      end
    end
  end
end
