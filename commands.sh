#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")

open-browser-aliases() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::System::OpenBrowserAliasesCommand" "$@"
  )
}

open-folder-aliases() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::System::OpenFolderAliasesCommand" "$@"
  )
}

setup-git-branch-issue() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::SetupGitBranchFromIssueCommand" "$@"
  )
}

setup-git-pull-request() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::SetupGitPullRequestCommand" "$@"
  )
}

setup-note-git-branch() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::SetupNoteFromGitBranchCommand" "$@"
  )
}

create-issue() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::CreateIssueCommand" "$@"
  )
}

setup-devflow() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::SetupDevflowCommand" "$@"
  )
}

setup-git-branch() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::SetupGitBranchCommand" "$@"
  )
}


alias b='open-browser-aliases'
alias f='open-folder-aliases'
alias branch-issue='setup-git-branch-issue'
alias pr='setup-git-pull-request'
alias note='setup-note-git-branch'
alias issue='create-issue'
alias devflow='setup-devflow'
alias branch='setup-git-branch'

workit-help() {
  echo "Available commands:"
  echo ""
  echo "System Commands:"
  echo "    open-browser-aliases (b)"
  echo "      Open browser URLs from configured aliases"
  echo ""
  echo "    open-folder-aliases (f)"
  echo "      Open folders from configured aliases"
  echo ""
  echo ""
  echo "Workflows Commands:"
  echo "    setup-git-branch-issue (branch-issue)"
  echo "      Setup development branch from issue tracker for new work"
  echo ""
  echo "    setup-git-pull-request (pr)"
  echo "      Setup pull request with issue integration"
  echo ""
  echo "    setup-note-git-branch (note)"
  echo "      Create notes with branch and issue context"
  echo ""
  echo "    create-issue (issue)"
  echo "      Create issue via API with automatic sprint assignment"
  echo ""
  echo "    setup-devflow (devflow)"
  echo "      Interactive development workflow (issue → branch → notes → PR)"
  echo ""
  echo "    setup-git-branch (branch)"
  echo "      Setup development branch for new work"
  echo ""
  echo ""
  echo ""
  echo "Use 'command-name --help' for detailed help on each command"
}

alias help='workit-help'
alias h='workit-help'
