
SCRIPT_DIR=$(dirname "$(realpath "$0")")
COMMAND_SCRIPT="${SCRIPT_DIR}/command.rb"

issue() {
  ruby "$COMMAND_SCRIPT" "create_issue_command" "$@"
}

git-flow() {
    ruby "$COMMAND_SCRIPT" "create_git_flow_command" "$@"
}
alias flow='git-flow'

git-bump() {
  ruby "$COMMAND_SCRIPT" "create_git_bump_command" "$@"
}
alias bump='git-bump'

open-pr() {
  ruby "$COMMAND_SCRIPT" "open_pr_command" "$@"
}
alias pr='open_pr'

open-browser-aliases() {
  ruby "$COMMAND_SCRIPT" "open_browser_aliases_command" "$@"
}
alias a='open-browser-aliases'

open-file-explorer-aliases() {
  ruby "$COMMAND_SCRIPT" "open_file_explorer_aliases_command" "$@"
}
alias o='open-file-explorer-aliases'


# GIT
alias amend='git amend'
alias wip='git wip'
commit() {
  git add .
  git commit -m "$*"
}
alias co='git co'
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
