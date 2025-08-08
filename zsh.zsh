
SCRIPT_DIR=$(dirname "$(realpath "$0")")
COMMAND_SCRIPT="${SCRIPT_DIR}/command.rb"

jira-ticket() {
    ruby "$COMMAND_SCRIPT" "create_jira_ticket_command" "$@"
}
alias ticket='jira-ticket'

git-branch() {
    ruby "$COMMAND_SCRIPT" "create_git_branch_command" "$@"
}
alias branch='git-branch'

git-bump() {
    local script_path="${JIRA_BASE_SCRIPT}/git_bump.rb"
    ruby "$script_path" "$@"
}
alias bump='git-bump'
