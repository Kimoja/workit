require_relative '../clients/jira_clients'
require_relative '../clients/github_clients'
require_relative '../services/create_git_branch_service'

module Commands
  def self.create_git_branch_command
    options = {}
  
    OptionParser.new do |opts|
      opts.banner = "Usage: #[OPTIONS] \"NOM_DE_LA_BRANCH\""
      opts.separator ""
      opts.separator "Arguments:"
      opts.separator "  NOM_DE_LA_BRANCH  Nom de la branche (optionnel si --jira-ticket défini)"
      opts.separator ""
      opts.separator "Options:"
      
      opts.on('-t', '--jira-ticket TICKET', 'Jira ticket (e.g., KRAFT-3735)') do |ticket|
        options[:jira_ticket] = ticket
      end
      
      opts.on("-h", "--help", "Affiche cette aide") do
        log opts
        log ""
        log "Exemples:"
        log "  git-branch \"Corriger le bug de connexion\""
        log "  branch -t KRAFT-3735"
        log ""
        log "Configuration:"
        log "  La commande utilise le ficher de configuration config.json"
        exit
      end
      
      opts.on("-v", "--version", "Affiche la version") do
        log "Jira Ticket (Cache avec clés string)"
        exit
      end
    end.parse!

    name = ARGV[0]
    jira_ticket = options[:jira_ticket]

    jira_client = Clients::JiraClient.build_from_config!(config)
    github_client = Clients::GithubClient.build_from_config!(config)

    validate_git_branch_command_inputs!(name:, jira_ticket:)

    create_git_branch_service = Tasks::CreateGitBranchService.new(
      name:,
      jira_ticket:, 
      jira_client:,
      github_client:
    )
    
    create_git_branch_service.call
  end

  def self.validate_git_branch_command_inputs!(name:, jira_ticket:)
    if (name.nil? || name.strip.empty?) && (jira_ticket.nil? || jira_ticket.strip.empty?)
      log_error "Le nom de la branche obligatoire ou le ticket jira est nécessaire"
      exit 1
    end

    log_success "Paramètres d'entrée validés"
  end
end