
SCRIPT_DIR=$(dirname "$(realpath "$0")")
COMMAND_SCRIPT="${SCRIPT_DIR}/command.rb"

jira-ticket() {
    ruby "$COMMAND_SCRIPT" "create_jira_ticket_command" "$@"
}
alias ticket='jira-ticket'

git-flow() {
    ruby "$COMMAND_SCRIPT" "create_git_flow_command" "$@"
}
alias flow='git-flow'

git-bump() {
    ruby "$COMMAND_SCRIPT" "create_git_bump_command" "$@"
}
alias bump='git-bump'
