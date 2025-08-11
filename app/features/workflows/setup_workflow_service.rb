module Features
  module Workflows
    class SetupWorkflowService < Service
      attr_reader(
        :branch_name,
        :issue_key,
        :issue_client,
        :git_repo_client
      )

      def call
        check_branch_not_protected!
        Workflows.checkout_git_branch(branch_name:, commit_message:)
        # Workflows.setup_pull_request()

        # existing_pr = Workflows.get_existing_pull_request(**Git.repo_info, branch_name:, git_repo_client:)
      end

      private

      def with_issue
        !!issue_key
      end

      def issue
        @issue ||= with_issue ? fetch_issue : nil
      end

      def branch_name
        @branch_name ||= with_issue ? create_branch_name_from_issue : raise('Branch name is required when no issue is provided')
      end

      def commit_message
        @commit_message ||= with_issue ? create_commit_message_from_issue : create_commit_message_from_branch_name
      end

      def description
        @description ||= with_issue ? issue.description : commit_message
      end

      def issue_type
        @issue_type ||=  with_issue ? issue.issue_type : get_issue_type_from_branch_name
      end

      def fetch_issue
        Log.info "Fetching Issue: #{issue_key}"

        issue_client.fetch_issue(issue_key)
      end

      def create_commit_message_from_branch_name
        # Extract prefix and suffix
        if branch_name.match(%r{^(fix|feat|feature|bug|hotfix|chore|docs|style|refactor|test)/(.+)$})
          prefix = ::Regexp.last_match(1).upcase
          suffix = ::Regexp.last_match(2)

          # Transform suffix: replace dashes with spaces and capitalize
          title = suffix.gsub('-', ' ').strip.capitalize

          "[#{prefix}] #{title}"
        else
          # If no recognized prefix, just transform the whole string
          branch_name.gsub('-', ' ').strip.capitalize
        end
      end

      def create_commit_message_from_issue
        type_prefix = issue.issue_type == 'bug' ? '[FIX]' : '[FEAT]'

        commit_message = "#{type_prefix} #{issue.key} - #{issue.title}"
        Log.info "Commit message: #{commit_message}"

        commit_message
      end

      def get_issue_type_from_branch_name
        if branch_name.match(%r{^(fix|bug)/})
          'bug'
        elsif branch_name.match(%r{^(bump)/})
          'bump'
        else
          'feat'
        end
      end

      def check_branch_not_protected!
        return unless Git.branch_protected?(branch_name)

        raise "Branch '#{branch_name}' is protected. Please switch to another branch or create a new one."
      end

      def create_pull_request
        Log.info 'Creating pull request...'

        Features::Workflows.create_pull_request.call(
          title: commit_message,
          head: branch_name,
          base: Git.main_branch_name,
          description:,
          issue_type:,
          git_repo_client:,
          issue:
        )
      end

      def create_branch_document
        # Vérifier que le dossier parent contient le suffixe "workspace"
        current_dir = Dir.pwd
        parent_dir = File.basename(File.dirname(current_dir))

        unless parent_dir.include?('workspace')
          Log.warn(
            "Skipping branch document creation - parent directory '#{parent_dir}' " \
            "does not contain 'workspace' suffix"
          )
          return
        end

        Log.info 'Creating branch document in workspace...'

        prs_dir = File.join(current_dir, '.branchess')
        existing_document = find_existing_branch_document(prs_dir, branch_name)

        if existing_document
          Log.info "Branch document already exists: #{existing_document}"
          return existing_document
        end

        # Créer le nom du dossier avec date et nom de branche
        date = Time.now.strftime('%Y-%m-%d')
        folder_name = "#{date}-#{branch_name}"
        branch_dir = File.join(prs_dir, folder_name)
        index_file = File.join(branch_dir, 'index.md')

        begin
          FileUtils.mkdir_p(branch_dir)
          content = "#[#{commit_message}](#{pr_url})"
          File.write(index_file, content)

          Log.success "Branch document created: #{index_file}"
          index_file
        rescue StandardError => e
          Log.error "Failed to create branch document: #{e.message}"
          nil
        end
      end

      def find_existing_branch_document(prs_dir, branch_name)
        return nil unless Dir.exist?(prs_dir)

        pattern = File.join(prs_dir, "*-#{branch_name}")
        matching_dirs = Dir.glob(pattern).select { |path| File.directory?(path) }

        matching_dirs.each do |dir|
          index_file = File.join(dir, 'index.md')
          return index_file if File.exist?(index_file)
        end

        nil
      end
    end
  end
end
