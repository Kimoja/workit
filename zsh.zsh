
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Format : function_name;ruby_class;[alias]
ruby_commands=(
  "create-issue;CreateIssueCommand;issue"
  "setup-git-branch;SetupGitBranchCommand;branch"
  "setup-git-branch-issue;SetupGitBranchFromIssueCommand;branch-issue"
  "setup-git-pull-request;SetupGitPullRequestCommand;pr"
  "setup-note-git-branch;SetupNotesFromGitBranchCommand;note"


  "setup-workflow;SetupWorkflowCommand;flow"
  "git-bump;CreateGitBumpCommand;bump"
  "open-browser-aliases;OpenBrowserAliasesCommand;a"
  "open-file-explorer-aliases;OpenFileExplorerAliasesCommand;o"
)

for entry in "${ruby_commands[@]}"; do
  IFS=';' read -r func_name ruby_cmd alias_name <<< "$entry"

  eval "
    $func_name() {
      local base_dir=\"\$PWD\"
      (
        cd \"\$SCRIPT_DIR\"
        bundle exec ruby app.rb \"\$base_dir\" \"$ruby_cmd\" \"\$@\"
      )
    }
  "

  if [ -n "$alias_name" ]; then
    eval "alias $alias_name='$func_name'"
  fi
done


# GIT
alias amend='git amend'
alias wip='git wip'
commit() {
  git add .
  git commit -m "$*"
}
alias push='git pushf'
# alias rebase='TMP_REBASE_BRANCH=$(git rev-parse --abbrev-ref HEAD); git co master; git pull; git co $TMP_REBASE_BRANCH; git rebase master'
alias rebase='git rsync'
# alias main='git co master; git pull'
base() {
  git co $(git base)
  git pull
}

# alias cop=' bundle exec rubocop --parallel -a'
# alias syncro='amend; push -f; bundle exec cap staging1 deploy'

# # Tunnels
# alias kstun='ssh -Ng -L 5434:localhost:5432 kustom@ku-staging-web-2-dc5.cheerz.net'
# alias kptun='ssh -Ng -L 5435:localhost:5432 kustom@ku-prod-db-2-dc5.cheerz.net'

# # Rails consoles
# alias ksc='ssh -t kustom@ku-staging-web-1-dc2.cheerz.net "cd kustom/current; rails console"'
# alias kpc='ssh -t kustom@ku-prod-web-1-dc2.cheerz.net "cd kustom/current; rails console"'

# # Deploy
# alias ksdep='bundle exec cap staging1 deploy'
# alias kpdep='bundle exec cap production deploy'

# # Browse
# alias aks='open https://kustom-staging.cheerz.com/admin_panel'
# alias akp='open https://kustom.cheerz.com/admin_panel'


# CHEERZ

alias kogen='open /Users/joakimcarrilho/dev/konnektor_workspace/konnektor/tmp/generation'
alias kgen='open /Users/joakimcarrilho/dev/kustom_workspace/kustom-backend/tmp/generations'
