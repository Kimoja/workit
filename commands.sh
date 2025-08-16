#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")

open-browser-aliases() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Open::BrowserAliasesCommand" "$@"
  )
}

setup-note-git-branch() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::SetupNoteFromGitBranchCommand" "$@"
  )
}

setup-workflow() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::SetupWorkflowCommand" "$@"
  )
}

create-issue() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::CreateIssueCommand" "$@"
  )
}

setup-git-branch() {
  local base_dir="$PWD"
  (
    cd "$SCRIPT_DIR"
    bundle exec ruby app.rb "$base_dir" "Commands::Workflows::SetupGitBranchCommand" "$@"
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


alias bro='open-browser-aliases'
alias note='setup-note-git-branch'
alias flow='setup-workflow'
alias issue='create-issue'
alias branch='setup-git-branch'
alias branch-issue='setup-git-branch-issue'
alias pr='setup-git-pull-request'

workit-help() {
  echo "Available commands:"
  echo ""
  echo "Open Commands:"
  echo "    open-browser-aliases (bro)"
  echo "      Open browser URLs from configured aliases"
  echo ""
  echo ""
  echo "Workflows Commands:"
  echo "    setup-note-git-branch (note)"
  echo "      Create notes with branch and issue context"
  echo ""
  echo "    setup-workflow (flow)"
  echo "      Interactive development workflow (issue → branch → notes → PR)"
  echo ""
  echo "    create-issue (issue)"
  echo "      Create issue via API with automatic sprint assignment"
  echo ""
  echo "    setup-git-branch (branch)"
  echo "      Setup development branch for new work"
  echo ""
  echo "    setup-git-branch-issue (branch-issue)"
  echo "      Setup development branch from issue tracker for new work"
  echo ""
  echo "    setup-git-pull-request (pr)"
  echo "      Setup pull request with issue integration"
  echo ""
  echo ""
  echo ""
  echo "Use 'command-name --help' for detailed help on each command"
}

alias help='workit-help'
alias h='workit-help'
