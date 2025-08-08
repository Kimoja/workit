#!/usr/bin/env ruby

def git_find_repo
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

  log "Error: No git repository found"
  exit 1
end

def git_repo_exists?(path)
  File.directory?(File.join(path, '.git'))
end

def git_commit_if_changes(commit_message: "WIP autocommit")
  if git_has_changes?
    log "Changes detected, creating WIP commit..."
    system("git add . && git commit -m '#{commit_message}'") || raise('Failed to create WIP commit')
  else
    log "No changes to commit"
  end
end

def git_has_changes?
  !`git status --porcelain`.strip.empty?
end

def git_switch_to_head_branch
  main_branch_name = git_head_branch_name
  log "Switching to #{main_branch_name} branch..."
  system("git checkout #{main_branch_name} && git pull") || raise('Failed to switch to master branch')
end

def git_create_branch(branch_name)
  system("git checkout -b #{branch_name}") || raise("Failed to create branch: #{branch_name}")
end

def git_push_branch
  log "Pushing branch..."

  system('git push -f') || raise('Failed to push branch')
end

def git_head_branch_name
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