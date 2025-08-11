module Utils
  module Git2
    extend self

    GIT_PROTECTED_BRANCHES = %w[
      main master develop dev development
      staging stage production prod release
      hotfix integration
    ].freeze

    def navigate_to_repo
      if repo_exists?('.')
        Log.info 'Git repository found in current directory'
        return
      end

      Log.info 'No git repository in current directory, searching in subdirectories...'

      Dir.glob('*/').each do |dir|
        next unless repo_exists?(dir)

        Log.info "Git repository found in #{dir}"
        Dir.chdir(dir)
        return
      end

      raise 'No git repository found'
    end

    def repo_info
      remote_url = `git config --get remote.origin.url`.strip

      # SSH : git@provider:owner/repo.git
      if remote_url =~ %r{\Agit@([^:]+):([^/]+)/([^.]+)(?:\.git)?\z}
        provider = Regexp.last_match(1)
        owner    = Regexp.last_match(2)
        repo     = Regexp.last_match(3)
      # HTTPS : https://provider/owner/repo(.git)
      elsif remote_url =~ %r{\Ahttps?://([^/]+)/([^/]+)/([^.]+)(?:\.git)?\z}
        provider = Regexp.last_match(1)
        owner    = Regexp.last_match(2)
        repo     = Regexp.last_match(3)
      else
        raise "Unable to parse repository information from remote URL: #{remote_url}"
      end

      { provider: provider, owner: owner, repo: repo }
    end

    def repo_exists?(path)
      File.directory?(File.join(path, '.git'))
    end

    def commit(message, *options)
      Log.info 'Creating commit...'
      system("git add . && git commit -m '#{message}' #{options.join}") || raise('Failed to create commit')
      Log.succes 'Commit created successfully!'
    end

    def branch_protected?(branch)
      GIT_PROTECTED_BRANCHES.include?(branch)
    end

    def stash_changes_if_protected_branch(raise_on_no: true)
      return unless branch_protected?(current_branch) && changes?

      Log.warn "Changes detected on a protected branch: '#{current_branch}'"
      Log.log 'Protected branches should not be modified directly.'

      Prompt.yes_no(
        text: 'Do you want to stash your changes and continue? (y/N):',
        yes: proc {
          stash_changes
          Log.success 'Changes stashed successfully'
        },
        no: proc {
          break unless raise_on_no

          raise "Operation cancelled, Cannot proceed on protected branch '#{current_branch}' with uncommitted changes"
        }
      )
      nil
    end

    def stash_changes
      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      branch_name = current_branch
      stash_message = "Auto-stash from #{branch_name} - #{timestamp}"

      Log.info 'Stashing changes...'

      result = system("git stash push -m '#{stash_message}'")

      unless result
        Play.error
        raise 'Failed to stash changes'
      end

      Log.success "Changes stashed with message: '#{stash_message}'"
      stash_message
    end

    def branch_exists?(branch_name)
      system("git show-ref --verify --quiet refs/heads/#{branch_name}")
    end

    def checkout(branch_name)
      Log.info "Switching to #{branch_name} branch..."
      system("git checkout #{branch_name}") || raise("Failed to switch to #{branch_name} branch")
    end

    def pull
      Log.info 'Pulling latest changes...'
      system('git pull') || raise('Failed to pull latest changes')
    end

    def cherry_pick(sha)
      Log.info "Cherry-picking commit #{sha}..."
      system("git cherry-pick #{sha}")
    end

    def revert(sha)
      Log.info "Reverting commit #{sha}..."
      system("git revert --no-edit #{sha}")
    end

    def create_branch(branch_name)
      system("git checkout -b #{branch_name}") || raise("Failed to create branch: #{branch_name}")
    end

    def branch_exists?(branch_name)
      !!system("git show-ref --verify --quiet refs/heads/#{branch_name}")
    end

    def push_branch
      Log.info 'Pushing branch...'

      system('git push -f') || raise('Failed to push branch')
    end

    def main_branch_name
      result = `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null`.strip

      return result.split('/').last if $?.success? && !result.empty?

      branches = `git branch -r`.lines.map(&:strip)

      if branches.any? { |branch| branch.include?('origin/main') }
        return 'main'
      elsif branches.any? { |branch| branch.include?('origin/master') }
        return 'master'
      end

      current_branch = current_branch
      current_branch.empty? ? 'main' : current_branch
    end

    def fetch_branch(branch_name)
      Log.info "Fetching branch '#{branch_name}' from origin..."

      system("git fetch origin #{branch_name}:#{branch_name}")
    end

    def current_branch
      `git branch --show-current`.strip
    end
  end
end
