module Services
  class CreateJiraTicketService
    def initialize(title:, board_name:, issue_type:, assignee_name:, jira_url:, jira_client:)
      @title = title
      @board_name = board_name
      @issue_type = issue_type
      @assignee_name = assignee_name
      @jira_url = jira_url
      @jira_client = jira_client
    end

    def call
      display_info

      board_id = find_board_id(@board_name)
      board_info = get_board_info(board_id)
      project_key = board_info['project_key']
      board_type = board_info['type']
      
      sprint_id = nil
      sprint_field_id = nil
      
      if board_type == 'scrum'
        sprint_field_id = find_sprint_field_id
        sprint_id = find_active_sprint(board_id)
      end
      # NE MODIFIE PAS LE BINDING.PRY ET RAISE
      binding.pry 
      raise 
      user_id = find_user_id(@assignee_name)
      issue_key = create_issue(@title, sprint_id, sprint_field_id, user_id, @issue_type, project_key)

      display_success(issue_key, board_type, sprint_id)

      url = "#{@jira_url}/browse/#{issue_key}"

      open_ticket(url)
      
      cache_set("last_jira_ticket", { 
        'url' =>url, 
        'issue_key' => issue_key 
      })
    end

    private

    def display_info
      log "🚀 Création d'un ticket Jira"
      log "Board: #{@board_name}"
      log "Titre: #{@title}"
      log "Type: #{@issue_type}"
      log "Assigné: #{@assignee_name}"
      log ""
    end

    def find_board_id(board_name)
      cache_key = "board_id_#{board_name.downcase.gsub(/\s+/, '_')}"
      
      # Vérification du cache
      cached_result = cache_get(cache_key)
      if cached_result
        log "🔍 Board '#{board_name}' trouvé dans le cache"
        log_success "Board trouvé: ID #{cached_result['id']} (Type: #{cached_result['type']})"
        return cached_result['id']
      end
      
      log "🔍 Recherche du board '#{board_name}'..."

      response = @jira_client.get('/rest/agile/1.0/board')
      board = response['values'].find { |b| b['name'].match(/#{Regexp.escape(board_name)}/i) }
      
      unless board
        log_error "Board '#{board_name}' introuvable"
        log "Boards disponibles:"
        response['values'].each { |b| log "  - #{b['name']} (#{b['type']})" }
        raise "Board introuvable"
      end
      
      log_success "Board trouvé: ID #{board['id']} (Type: #{board['type']})"
      
      # Mise en cache avec clés string
      cache_set(cache_key, { 
        'id' => board['id'], 
        'type' => board['type'] 
      })
      
      board['id']
    end

    def get_board_info(board_id)
      cache_key = "board_info_#{board_id}"
      
      # Vérification du cache
      cached_result = cache_get(cache_key)
      if cached_result
        log "🔍 Informations du board trouvées dans le cache"
        log_success "Type de board: #{cached_result['type']}"
        log_success "Projet associé: #{cached_result['project_key']}"
        return cached_result
      end
      
      log "🔍 Récupération des informations du board..."
      
      response = @jira_client.get("/rest/agile/1.0/board/#{board_id}")
      board_type = response['type'].downcase
      project_key = extract_project_key(board_id, response)
      
      unless project_key
        raise "Impossible de déterminer le projet associé au board"
      end
      
      log_success "Type de board: #{board_type}"
      log_success "Projet associé: #{project_key}"
      
      result = {
        'type' => board_type,
        'project_key' => project_key
      }
      
      # Mise en cache
      cache_set(cache_key, result)
      
      result
    end

    def extract_project_key(board_id, response)
      # Méthode 1: Directement depuis les informations du board
      if response['location'] && response['location']['projectKey']
        return response['location']['projectKey']
      end

      # Méthode 2: Via la configuration du board
      begin
        config_response = @jira_client.get("/rest/agile/1.0/board/#{board_id}/configuration")
        if config_response['location'] && config_response['location']['projectKey']
          return config_response['location']['projectKey']
        end
      rescue => e
        log_warning "Impossible de récupérer la configuration du board: #{e.message}"
      end
      
      # Méthode 3: Via les issues du board (dernier recours)
      begin
        issues_response = @jira_client.get("/rest/agile/1.0/board/#{board_id}/issue?maxResults=1")
        if issues_response['issues'] && issues_response['issues'].any?
          return issues_response['issues'].first['fields']['project']['key']
        end
      rescue => e
        log_warning "Impossible de récupérer les issues du board: #{e.message}"
      end
      
      nil
    end

    def find_active_sprint(board_id)
      # Les sprints actifs changent fréquemment, pas de cache pour cette méthode
      log "🔍 Recherche du sprint actif..."
      
      begin
        response = @jira_client.get("/rest/api/2/field")
        sprint = response['values'].first
        binding.pry
        # @jira_client.get("/rest/agile/1.0/board/#{board_id}/sprint?state=active")
        if sprint
          log_success "Sprint actif trouvé: '#{sprint['name']}' (ID: #{sprint['id']})"
          return sprint['id']
        else
          log_warning "Aucun sprint actif trouvé"
          display_future_sprints(board_id)
          return nil
        end
      rescue => e
        log_warning "Erreur lors de la recherche de sprint: #{e.message}"
        log "📦 Le ticket sera créé dans le backlog"
        return nil
      end
    end

    def display_future_sprints(board_id)
      future_response = @jira_client.get("/rest/agile/1.0/board/#{board_id}/sprint?state=future")
      if future_response['values'].any?
        log "📋 Sprints futurs disponibles:"
        future_response['values'].first(3).each do |s|
          log "   - #{s['name']}"
        end
        log "💡 Astuce: Vous pouvez démarrer un sprint depuis l'interface Jira"
      end
    end

    def find_sprint_field_id
      cache_key = "sprint_field_id"
      
      # Vérification du cache
      cached_result = cache_get(cache_key)
      if cached_result
        log "🔍 ID du champ Sprint trouvé dans le cache"
        log "📋 Board Scrum détecté - gestion des sprints activée"
        log_success "Champ Sprint trouvé: #{cached_result}"
        return cached_result
      end
      
      log "🔍 Recherche de l'ID du champ Sprint..."
      log "📋 Board Scrum détecté - gestion des sprints activée"
      
      begin
        response = @jira_client.get('/rest/api/2/field')
        field = response.find { |f| f['name'] == 'Sprint' }
        
        unless field
          log_warning "Champ Sprint introuvable - board sans sprints ou configuration manquante"
          return nil
        end
        
        log_success "Champ Sprint trouvé: #{field['id']}"
        
        # Mise en cache (valeur directe, pas de hash)
        cache_set(cache_key, field['id'])
        
        field['id']
      rescue => e
        log_warning "Erreur lors de la recherche du champ Sprint: #{e.message}"
        return nil
      end
    end

    def find_user_id(display_name)
      cache_key = "user_id_#{display_name.downcase.gsub(/\s+/, '_')}"
      
      # Vérification du cache
      cached_result = cache_get(cache_key)
      if cached_result
        log "🔍 Utilisateur '#{display_name}' trouvé dans le cache"
        if cached_result == 'not_found'  # String au lieu de symbol
          log_warning "Utilisateur '#{display_name}' introuvable (cache), le ticket sera non assigné"
          return nil
        else
          log_success "Utilisateur trouvé: #{cached_result['display_name']}"
          return cached_result['account_id']
        end
      end
      
      log "🔍 Recherche de l'utilisateur '#{display_name}'..."
      
      encoded_name = URI.encode_www_form_component(display_name)
      response = @jira_client.get("/rest/api/3/user/search?query=#{encoded_name}")
      
      user = response.find { |u| u['displayName'].match(/#{Regexp.escape(display_name)}/i) }
      
      unless user
        log_warning "Utilisateur '#{display_name}' introuvable, le ticket sera non assigné"
        # Mise en cache du résultat négatif (string)
        cache_set(cache_key, 'not_found')
        return nil
      end
      
      log_success "Utilisateur trouvé: #{user['displayName']}"
      
      # Mise en cache avec clés string
      cache_set(cache_key, { 
        'account_id' => user['accountId'], 
        'display_name' => user['displayName'] 
      })
      
      user['accountId']
    end

    def validate_issue_type(issue_type, project_key)
      cache_key = "issue_types_#{project_key}"
      
      # Vérification du cache
      cached_types = cache_get(cache_key)
      if cached_types
        log "🔍 Types d'issues pour le projet #{project_key} trouvés dans le cache"
        return find_matching_issue_type(issue_type, cached_types, project_key)
      end
      
      log "🔍 Validation du type d'issue '#{issue_type}' pour le projet #{project_key}..."
      
      begin
        response = @jira_client.get("/rest/api/2/issue/createmeta?projectKeys=#{project_key}&expand=projects.issuetypes")
        
        project = response['projects'].first
        unless project
          log_warning "Impossible de valider le type d'issue, utilisation sans validation"
          return issue_type
        end
        
        available_types = project['issuetypes'].map { |it| it['name'] }
        
        # Mise en cache (array directement)
        cache_set(cache_key, available_types)
        
        return find_matching_issue_type(issue_type, available_types, project_key)
        
      rescue => e
        log_warning "Erreur lors de la validation du type d'issue: #{e.message}"
        log "Utilisation du type spécifié sans validation: #{issue_type}"
        return issue_type
      end
    end

    def find_matching_issue_type(issue_type, available_types, project_key)
      # Recherche exacte d'abord
      exact_match = available_types.find { |type| type.downcase == issue_type.downcase }
      return exact_match if exact_match
      
      # Recherche partielle si pas de correspondance exacte
      partial_match = available_types.find { |type| type.downcase.include?(issue_type.downcase) }
      if partial_match
        log_success "Type d'issue trouvé: '#{partial_match}' (correspondance partielle)"
        return partial_match
      end

      # Aucune correspondance trouvée
      log_error "Type d'issue '#{issue_type}' introuvable"
      log "Types disponibles pour le projet #{project_key}:"
      available_types.each { |type| log "  - #{type}" }
      raise "Type d'issue invalide"
    end

    def create_issue(title, sprint_id, sprint_field_id, user_id, issue_type, project_key)
      log "🎫 Création du ticket..."
      
      validated_type = validate_issue_type(issue_type, project_key)
      
      payload = {
        fields: {
          project: { key: project_key },
          summary: title,
          description: "Ticket créé automatiquement via script CLI Ruby",
          issuetype: { name: validated_type }
        }
      }
      
      if sprint_id && sprint_field_id
        payload[:fields][sprint_field_id] = sprint_id
        log "📌 Ajout au sprint actif"
      else
        log "📦 Création dans le backlog"
      end
      
      payload[:fields][:assignee] = { id: user_id } if user_id
      
      response = @jira_client.post('/rest/api/2/issue', payload)
      response['key']
    end

    def display_success(issue_key, board_type, sprint_id)
      log_success "Ticket créé avec succès: #{issue_key}"
      log "🔗 URL: #{@jira_url}/browse/#{issue_key}"
      
      if board_type == 'scrum' && sprint_id.nil?
        log "📦 Ticket ajouté au backlog du projet"
      elsif board_type == 'scrum' && sprint_id
        log "🏃 Ticket ajouté au sprint actif"
      else
        log "📋 Ticket ajouté au board Kanban"
      end
      
      log ""
      log_success "🎉 Terminé!"
    end

    def open_ticket(url)
      case RUBY_PLATFORM
      when /darwin/
        `open "#{url}"`
      when /linux/
        `xdg-open "#{url}"`
      when /mswin|mingw|cygwin/
        `start "#{url}"`
      else
        log "🌐 Ouvrez manuellement: #{url}"
      end
    end
  end
end