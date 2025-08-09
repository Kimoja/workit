GIT_PROTECTED_BRANCHES = %w[
  main master develop dev development
  staging stage production prod release
  hotfix integration
].freeze

def git_navigate_to_repo!
  if git_repo_exists?('.')
    log_info "Git repository found in current directory"
    return
  end

  log_info "No git repository in current directory, searching in subdirectories..."
  
  Dir.glob('*/').each do |dir|
    if git_repo_exists?(dir)
      log_info "Git repository found in #{dir}"
      Dir.chdir(dir)
      return
    end
  end

  raise "No git repository found"
end

def git_repo_exists?(path)
  File.directory?(File.join(path, '.git'))
end

def git_commit(message, *options)
  log_info "Creating commit..."

  system("git add . && git commit -m '#{message}' #{options.join}") || raise('Failed to create commit')
end

def git_branch_protected?(branch)
  GIT_PROTECTED_BRANCHES.include?(branch)
end

def git_stash_changes_if_protected_branch
  current_branch = git_current_branch
  if git_branch_protected?(current_branch) && git_has_changes?
    log_warning "Changes detected on a protected branch: '#{current_branch}'"
    log "Protected branches should not be modified directly."
    yes_no(
      text: "Do you want to stash your changes and continue? (y/N):",
      yes: proc {
        git_stash_changes
        log_success "Changes stashed successfully"
      },
      no: proc {
        raise "Operation cancelled, Cannot proceed on protected branch '#{current_branch}' with uncommitted changes"
      }
    )
    return
  end
end

def git_stash_changes
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  branch_name = git_current_branch
  stash_message = "Auto-stash from #{branch_name} - #{timestamp}"
  
  log_info "Stashing changes..."
  
  result = system("git stash push -m '#{stash_message}'")
  
  unless result
    play_error_sound
    raise "Failed to stash changes"
  end
  
  log_success "Changes stashed with message: '#{stash_message}'"
  stash_message
end

def git_commit_if_changes(message = "WIP autocommit")
  if git_has_changes?
    log_info "Changes detected"
    git_commit(message)
  else
    log_info "No changes to commit"
  end
end

def git_has_changes?
  !`git status --porcelain`.strip.empty?
end

def git_checkout(branch_name)
  log_info "Switching to #{branch_name} branch..."
  system("git checkout #{branch_name}") || raise("Failed to switch to #{branch_name} branch")
end

def git_pull
  log_info "Pulling latest changes..."
  system("git pull") || raise("Failed to pull latest changes")
end

def git_cherry_pick(sha)
  log_info "Cherry-picking commit #{sha}..."
  system("git cherry-pick #{sha}")
end

def git_revert(sha)
  log_info "Reverting commit #{sha}..."
  system("git revert --no-edit #{sha}")
end

def git_create_branch(branch_name)
  system("git checkout -b #{branch_name}") || raise("Failed to create branch: #{branch_name}")
end

def git_branch_exists?(branch_name)
  !!system("git show-ref --verify --quiet refs/heads/#{branch_name}")
end

def git_push_branch
  log_info "Pushing branch..."

  system('git push -f') || raise('Failed to push branch')
end

def git_main_branch_name
  result = `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null`.strip
  
  if $?.success? && !result.empty?
    return result.split('/').last
  end
  
  branches = `git branch -r`.lines.map(&:strip)
  
  if branches.any? { |branch| branch.include?('origin/main') }
    return 'main'
  elsif branches.any? { |branch| branch.include?('origin/master') }  
    return 'master'
  end
  
  current_branch = git_current_branch
  return current_branch.empty? ? 'main' : current_branch
end

def git_fetch_branch(branch_name)
  log_info "Fetching branch '#{branch_name}' from origin..."
  
  system("git fetch origin #{branch_name}:#{branch_name}")
end
    
def git_current_branch
  `git branch --show-current`.strip
end