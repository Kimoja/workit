#!/usr/bin/env ruby

require_relative 'deps'

module Services 
  module Concerns
    module GitConcern
      def find_git_repo
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

      def commit_if_changes(commit_message: "WIP autocommit")
        if has_changes?
          puts "Changes detected, creating WIP commit..."
          system("git add . && git commit -m '#{commit_message}'") || raise('Failed to create WIP commit')
        else
          puts "No changes to commit"
        end
      end

      def has_changes?
        !`git status --porcelain`.strip.empty?
      end

      def switch_to_master
        puts "Switching to master branch..."
        system('git checkout master && git pull') || raise('Failed to switch to master branch')
      end

      def create_and_checkout_branch(branch_name)
        system("git checkout -b #{branch_name}") || raise("Failed to create branch: #{branch_name}")
      end

      def push_branch
        puts "Pushing branch..."

        system('git push -f') || raise('Failed to push branch')
      end
    end
  end
end