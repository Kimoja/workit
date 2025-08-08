
SCRIPT_DIR=$(dirname "$(realpath "$0")")
BOOTSTRAP_SCRIPT="${SCRIPT_DIR}/bootstrap.rb"

jira-ticket() {
    ruby "$BOOTSTRAP_SCRIPT" "Commands.create_jira_ticket_command" "$@"
}
alias jt='jira-ticket'
alias ticket='jira-ticket'

git-branch() {
    ruby "$BOOTSTRAP_SCRIPT" "Commands.create_git_branch_command" "$@"
}
alias gb='git-branch'
alias task='git-branch'

git-bump() {
    local script_path="${JIRA_BASE_SCRIPT}/git_bump.rb"
    ruby "$script_path" "$@"
}
alias bump='git-bump'
