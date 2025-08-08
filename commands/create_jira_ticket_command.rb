require_relative '../clients/jira_clients'
require_relative '../services/create_jira_ticket_service'

module Commands
  def self.create_jira_ticket_command
    options = {
      board: nil,
      type: nil
    }
    
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [OPTIONS] \"TITRE_DU_TICKET\""
      opts.separator ""
      opts.separator "Arguments:"
      opts.separator "  TITRE_DU_TICKET  Titre du ticket à créer (obligatoire)"
      opts.separator ""
      opts.separator "Options:"
      
      opts.on("-b", "--board BOARD", "Nom du board Jira (défaut: depuis config.json)") do |board|
        options[:board] = board
      end
      
      opts.on("-t", "--type TYPE", "Type d'issue Jira (défaut: depuis config.json)",
              "Types courants: Task, Story, Bug, Epic, Subtask") do |type|
        options[:type] = type
      end
      
      opts.on("-h", "--help", "Affiche cette aide") do
        log opts
        log ""
        log "Exemples:"
        log "  jira-ticket \"Corriger le bug de connexion\""
        log "  ticket -b KRAFT \"Implémenter la nouvelle fonctionnalité\""
        log "  ticket -t Bug \"Corriger l'affichage des images\""
        log "  ticket -b BT -t Task \"Interface utilisateur\""
        log ""
        log "Configuration:"
        log "  La commande utilise le ficher de configuration config.json"
        log ""
        log "Types de boards supportés:"
        log "  Scrum   - Avec sprints et backlog"
        log "  Kanban  - Sans sprints, flux continu"
        log ""
        log "Gestion des sprints:"
        log "  • Boards Scrum: ticket ajouté au sprint actif ou au backlog"
        log "  • Boards Kanban: ticket ajouté directement au board"
        log "  • Pas de sprint actif: ticket ajouté au backlog"
        exit
      end
      
      opts.on("-v", "--version", "Affiche la version") do
        log "Jira Ticket"
        exit
      end
    end.parse!

    title = ARGV[0]
    board_name = options[:board] || config.jira.default_board
    issue_type = options[:type] || config.jira.default_issue_type
    assignee_name = config.jira.assignee_name
    jira_url = config.jira.url

    jira_client = Clients::JiraClient.build_from_config!(config)
    
    validate_create_jira_ticket_command!(title:, board_name:, issue_type:, assignee_name:, jira_url:, jira_client:)

    create_jira_ticket_service = Services::CreateJiraTicketService.new(
      title:,
      board_name:,
      issue_type:,
      assignee_name:,
      jira_url:,
      jira_client:
    )
    
    create_jira_ticket_service.call
  end

  def self.validate_create_jira_ticket_command!(title:, board_name:, issue_type:, assignee_name:, jira_url:, jira_client:)

    if title.nil? || title.strip.empty?
      log_error "Le titre du ticket est obligatoire"
      exit 1
    end
    
    if board_name.nil? || board_name.strip.empty?
      log_error "Le nom du board est obligatoire"
      exit 1
    end
    
    if issue_type.nil? || issue_type.strip.empty?
      log_error "Le type d'issue est obligatoire"
      exit 1
    end
    
    if assignee_name.nil? || assignee_name.strip.empty?
      log_error "Le nom de l'assigné est obligatoire"
      exit 1
    end
    
    if jira_url.nil? || jira_url.strip.empty?
      log_error "L'URL Jira est obligatoire"
      exit 1
    end
    
    unless jira_url.match?(/\Ahttps?:\/\/.+\.atlassian\.net\z/)
      log_warning "Attention: L'URL Jira ne semble pas être une URL Atlassian standard"
      log "URL configurée: #{jira_url}"
    end

    log_success "Paramètres d'entrée validés"
  end
end