#!/usr/bin/env ruby

require_relative 'deps'

module GitConcern

  def git_navigate_to_repo!
    if git_repo_exists?('.')
      puts "Git repository found in current directory"
      return
    end

    puts "No git repository in current directory, searching in subdirectories..."
    
    Dir.glob('*/').each do |dir|
      if git_repo_exists?(dir)
        puts "Git repository found in #{dir}"
        Dir.chdir(dir)
        return
      end
    end

    puts "Error: No git repository found"
    exit 1
  end

  def git_repo_exists?(path)
    File.directory?(File.join(path, '.git'))
  end

  def git_commit_if_changes
    if git_has_changes?
      puts "Changes detected, creating WIP commit..."
      system('git add . && git commit -m "WIP autocommit"') || raise('Failed to create WIP commit')
    else
      puts "No changes to commit"
    end
  end

  def git_has_changes?
    !`git status --porcelain`.strip.empty?
  end

  def switch_to_master
    puts "Switching to master branch..."
    system('git checkout master && git pull') || raise('Failed to switch to master branch')
  end

  def create_and_checkout_branch(branch_name)
    system("git checkout -b #{branch_name}") || raise("Failed to create branch: #{branch_name}")
  end

  def git_push_branch
    puts "Pushing branch..."

    system('git push -f') || raise('Failed to push branch')
  end
end
