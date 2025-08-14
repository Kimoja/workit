module Domain
  module Workflows
    class CreatePullRequestAction
      include Action
      attr_reader(
        :title,
        :head,
        :base,
        :description,
        :issue_type,
        :git_repo_client,
        :repo,
        :owner,
        :issue
      )

      def call
        pull_request = git_repo_client.create_pull_request(
          owner,
          repo,
          {
            title:,
            head:,
            base:,
            body: prepare_pr_description
          }
        )

        url = pull_request['html_url']
        Log.success "Pull request created successfully: #{url}"
        add_to_cache(pull_request)

        url
      end

      private

      def get_existing_pr
        Cache.get("pr_#{repo}_#{branch_name}") || git_repo_client.fetch_pull_request_by_branch_name(owner, repo,
                                                                                                    branch_name)
      end

      def prepare_pr_description
        template = fetch_pr_template

        template = if issue_type == 'bug'
                     template.gsub(/- \[ \] [Bb]ug/, '- [x] Bug fix')
                   elsif issue_type == 'bump'
                     template.gsub(/- \[ \] .*?(gems|dependancies|dépendance).*?$/, '- [x] Mise à jour de gems')
                   else
                     template.gsub(/- \[ \] [Nn]ouvelle/, '- [x] Nouvelle fonctionnalité')
                   end

        if issue && issue.key && issue.url
          template = template.gsub(/(##\s*📔?\s*[Tt]icket[^:\n]*:?)[\s-]*(?=[^\s-]|$)/mi,
                                   "\\1\n\n- [#{issue.key}](#{issue.url})\n\n")
        end

        if description
          clean_description = description.gsub(/\{[^}]+\}/, '').strip
          template = template.gsub(/(##\s*📓?\s*[Dd]escription[^:\n]*:?)[\s-]*(?=[^\s-]|$)/mi,
                                   "\\1\n\n#{clean_description}\n\n")
        end

        template
      end

      def fetch_pr_template
        Log.info 'Fetching pull request template from local file...'

        template_path = File.join(Dir.pwd, 'pull_request_template.md')

        if File.exist?(template_path)
          Log.info "Found PR template at: #{template_path}"
          File.read(template_path)
        else
          Log.info "Warning: Could not find PR template at #{template_path}, using default template"
          get_default_template
        end
      rescue StandardError => e
        Log.error "Reading PR template file: #{e.message}"
        Log.log 'Using default template instead'
        get_default_template
      end

      def get_default_template
        default_template_path = File.join(APP_PATH, 'resources', 'default_pull_request_template.md')

        if File.exist?(default_template_path)
          Log.info "Using default template from: #{default_template_path}"
          File.read(default_template_path)
        else
          Log.warn "Default template not found at #{default_template_path}, using fallback template"
          get_fallback_template
        end
      rescue StandardError => e
        Log.error "Reading default template file: #{e.message}"
        Log.log 'Using fallback template instead'
        get_fallback_template
      end

      def get_fallback_template
        <<~TEMPLATE
          ## Description
          Brief description of the changes made.

          ## Changes
          - List of changes

          ## Testing
          How was this tested?

          ## Notes
          Any additional notes or considerations.
        TEMPLATE
      end

      def add_to_cache(pull_request)
        Cache.set("pr_#{repo}_#{head}", {
                    url: pull_request['html_url'],
                    number: pull_request['number'],
                    title: pull_request['title']
                  })
      end
    end
  end
end
