#!/usr/bin/env ruby

def git_navigate_to_repo!
  if git_repo_exists?('.')
    log "Git repository found in current directory"
    return
  end

  log "No git repository in current directory, searching in subdirectories..."
  
  Dir.glob('*/').each do |dir|
    if git_repo_exists?(dir)
      log "Git repository found in #{dir}"
      Dir.chdir(dir)
      return
    end
  end

  log_error "No git repository found"
  exit 1
end

def git_repo_exists?(path)
  File.directory?(File.join(path, '.git'))
end

def git_commit(message)
  log "Creating commit..."
  system("git add . && git commit -m '#{message}'") || raise('Failed to create commit')
end

def git_commit_empty(message)
  log "Creating empty commit..."
  system("git commit --allow-empty -m '#{message}'") || raise('Failed to create commit')
end

def git_commit_if_changes(message = "WIP autocommit")
  if git_has_changes?
    log "Changes detected"
    git_commit(message)
  else
    log "No changes to commit"
  end
end

def git_has_changes?
  !`git status --porcelain`.strip.empty?
end

def git_switch_to_main_branch
  main_branch_name = git_main_branch_name
  log "Switching to #{main_branch_name} branch..."
  system("git checkout #{main_branch_name} && git pull") || raise('Failed to switch to master branch')
end

def git_repo_info
  remote_url = `git config --get remote.origin.url`.strip
  
  if remote_url.match(/github\.com[\/:](.+)\/(.+)\.git$/)
    owner = $1
    repo = $2
    { owner: owner, repo: repo }
  else
    raise "Unable to parse GitHub repository information from remote URL: #{remote_url}"
  end
end

def git_create_branch(branch_name, ask_if_exists: false)
  # Check if branch already exists
  branch_exists = system("git show-ref --verify --quiet refs/heads/#{branch_name}")
  
  if branch_exists
    raise("Branch: #{branch_name} already exists") unless ask_if_exists

    log "Branch '#{branch_name}' already exists"

    yes_no(
      text: "Do you want to use the existing branch?", 
      yes: proc {
        log "Switching to existing branch '#{branch_name}'..."
        system("git checkout #{branch_name}") || raise("Failed to switch to branch: #{branch_name}")
      }, 
      no: proc {
        log_error "Operation cancelled"
        exit 1
      }
    )
  else
    # Create new branch
    system("git checkout -b #{branch_name}") || raise("Failed to create branch: #{branch_name}")
  end
end

def git_setup_branch_workflow(branch_name, ask_if_exists: true)
  git_navigate_to_repo!
  git_commit_if_changes
  git_switch_to_main_branch
  git_create_branch(branch_name, ask_if_exists: true)
end

def git_push_branch
  log "Pushing branch..."

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
  
  current_branch = `git branch --show-current`.strip
  return current_branch.empty? ? 'main' : current_branch
end

def git_fetch_branch(branch_name)
  log "Fetching branch '#{branch_name}' from origin..."
  
  system("git fetch origin #{branch_name}:#{branch_name}")
end
      