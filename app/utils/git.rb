module Utils
  module Git
    extend self

    GIT_PROTECTED_BRANCHES = %w[
      main master develop dev development
      staging stage production prod release
      hotfix integration
    ].freeze

    ### REPO ###
    def navigate_to_repo(&fallback)
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

      apply_fallback!(
        fallback,
        "No git repository found"
      )
    end

    def repo_exists?(path)
      File.directory?(File.join(path, '.git'))
    end

    def repo_info(&fallback)
      remote_url = `git config --get remote.origin.url`.strip

      match =
        remote_url.match(%r{\Agit@([^:]+):([^/]+)/([^.]+)(?:\.git)?\z}) ||
        remote_url.match(%r{\Ahttps?://([^/]+)/([^/]+)/([^.]+)(?:\.git)?\z})

      if match
        provider, owner, repo = match.captures
        return { provider: provider, owner: owner, repo: repo }
      end

      apply_fallback!(
        fallback,
        "Unable to parse repository information from remote URL: #{remote_url}"
      )
    end

    ### BRANCH ###

    def branch_exists?(branch_name)
      system("git show-ref --verify --quiet refs/heads/#{branch_name}")
    end

    def branch_protected?(branch)
      GIT_PROTECTED_BRANCHES.include?(branch)
    end

    def checkout(branch_name, &fallback)
      Log.info "Switching to #{branch_name} branch..."

      system("git checkout #{branch_name}") || apply_fallback!(
        fallback,
        "Failed to switch to #{branch_name} branch"
      )
    end

    def main_branch
      result = `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null`.strip

      return result.split('/').last if $CHILD_STATUS.success? && !result.empty?

      branches = `git branch -r`.lines.map(&:strip)

      if branches.any? { |branch| branch.include?('origin/main') }
        return 'main'
      elsif branches.any? { |branch| branch.include?('origin/master') }
        return 'master'
      end

      branch = current_branch
      branch.empty? ? 'main' : branch
    end

    def current_branch
      `git branch --show-current`.strip
    end

    def create_branch(branch_name, &fallback)
      Log.info "Creating branch: '#{branch_name}'"

      system("git checkout -b #{branch_name}") || apply_fallback!(
        fallback,
        "Failed to create branch: #{branch_name}"
      )
    end

    def pull(&fallback)
      Log.info 'Pulling latest changes with rebase...'

      system('git pull --rebase') || apply_fallback!(
        fallback,
        "Failed to pull latest changes for branch '#{current_branch}'"
      )
    end

    def push(&fallback)
      Log.info 'Pushing branch...'

      system('git push -f') || apply_fallback!(
        fallback,
        'Failed to push branch'
      )
    end

    def base_branch(&fallback)
      Log.info 'Searching for the base branch from remote branches...'

      # Récupérer toutes les branches remote
      all_remote_branches = `git branch -r --format='%(refname:short)'`.lines.map(&:strip)

      # Filtrer les branches remote pour exclure HEAD et la branche courante
      current_branch_name = current_branch
      all_remote_branches = all_remote_branches.reject do |branch|
        branch.include?('/HEAD') || branch == "origin/#{current_branch_name}"
      end

      results = []

      all_remote_branches.each do |remote_branch|
        merge_base = `git merge-base HEAD #{remote_branch} 2>/dev/null`.strip
        next if merge_base.empty?

        commits_ahead = `git rev-list --count #{merge_base}..HEAD`.strip.to_i
        commits_behind = `git rev-list --count HEAD..#{merge_base}`.strip.to_i
        commit_info = `git log -1 --format="%h %s %an %ad" --date=short #{merge_base}`.strip

        results << {
          branch: remote_branch,
          merge_base: merge_base,
          commits_ahead: commits_ahead,
          commits_behind: commits_behind,
          commit_info: commit_info
        }
      end

      results.min_by { |r| r[:commits_ahead] } || apply_fallback!(
        fallback,
        'Failed to find base branch'
      )
    end

    ### CHANGES ###

    def changes?
      !`git status --porcelain`.strip.empty?
    end

    def stash_changes(&fallback)
      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      branch_name = current_branch
      stash_message = "Auto-stash from #{branch_name} - #{timestamp}"

      Log.info "Stashing changes with message: '#{stash_message}'"

      system("git stash push -m '#{stash_message}'") || apply_fallback!(
        fallback,
        'Failed to stash changes'
      )
    end

    def commit(message, *options, &fallback)
      Log.info "Creating commit with message: '#{message}'"

      system("git add . && git commit -m '#{message}' #{options.join}") || apply_fallback!(
        fallback,
        'Failed to create commit'
      )
    end

    def abort_rebase(&fallback)
      system('git rebase --abort') || apply_fallback!(
        fallback,
        'Failed to abort rebase'
      )
    end

    ### MISC ###

    def apply_fallback!(fallback, error_message)
      Log.error(error_message)
      # binding.pry
      fallback&.call || raise(error_message)
    end
  end
end
