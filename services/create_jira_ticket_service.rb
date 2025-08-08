
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
    log "🚀 Creating Jira ticket"
    log "Board: #{@board_name}"
    log "Title: #{@title}"
    log "Type: #{@issue_type}"
    log "Assignee: #{@assignee_name}"
    log ""
  end

  def find_board_id(board_name)
    cache_key = "board_id_#{board_name.downcase.gsub(/\s+/, '_')}"
    
    # Cache verification
    cached_result = cache_get(cache_key)
    if cached_result
      log "🔍 Board '#{board_name}' found in cache"
      log_success "Board found: ID #{cached_result['id']} (Type: #{cached_result['type']})"
      return cached_result['id']
    end
    
    log "🔍 Searching for board '#{board_name}'..."

    response = @jira_client.get('/rest/agile/1.0/board')
    board = response['values'].find { |b| b['name'].match(/#{Regexp.escape(board_name)}/i) }
    
    unless board
      log_error "Board '#{board_name}' not found"
      log "Available boards:"
      response['values'].each { |b| log "  - #{b['name']} (#{b['type']})" }
      raise "Board not found"
    end
    
    log_success "Board found: ID #{board['id']} (Type: #{board['type']})"
    
    # Cache with string keys
    cache_set(cache_key, { 
      'id' => board['id'], 
      'type' => board['type'] 
    })
    
    board['id']
  end

  def get_board_info(board_id)
    cache_key = "board_info_#{board_id}"
    
    # Cache verification
    cached_result = cache_get(cache_key)
    if cached_result
      log "🔍 Board information found in cache"
      log_success "Board type: #{cached_result['type']}"
      log_success "Associated project: #{cached_result['project_key']}"
      return cached_result
    end
    
    log "🔍 Retrieving board information..."
    
    response = @jira_client.get("/rest/agile/1.0/board/#{board_id}")
    board_type = response['type'].downcase
    project_key = extract_project_key(board_id, response)
    
    unless project_key
      raise "Unable to determine project associated with board"
    end
    
    log_success "Board type: #{board_type}"
    log_success "Associated project: #{project_key}"
    
    result = {
      'type' => board_type,
      'project_key' => project_key
    }
    
    # Cache
    cache_set(cache_key, result)
    
    result
  end

  def extract_project_key(board_id, response)
    # Method 1: Directly from board information
    if response['location'] && response['location']['projectKey']
      return response['location']['projectKey']
    end

    # Method 2: Via board configuration
    begin
      config_response = @jira_client.get("/rest/agile/1.0/board/#{board_id}/configuration")
      if config_response['location'] && config_response['location']['projectKey']
        return config_response['location']['projectKey']
      end
    rescue => e
      log_warning "Unable to retrieve board configuration: #{e.message}"
    end
    
    # Method 3: Via board issues (last resort)
    begin
      issues_response = @jira_client.get("/rest/agile/1.0/board/#{board_id}/issue?maxResults=1")
      if issues_response['issues'] && issues_response['issues'].any?
        return issues_response['issues'].first['fields']['project']['key']
      end
    rescue => e
      log_warning "Unable to retrieve board issues: #{e.message}"
    end
    
    nil
  end

  def find_active_sprint(board_id)
    # Active sprints change frequently, no cache for this method
    log "🔍 Searching for active sprint..."
    
    begin
      response = @jira_client.get("/rest/api/2/field")
      sprint = response['values'].first
      binding.pry
      # @jira_client.get("/rest/agile/1.0/board/#{board_id}/sprint?state=active")
      if sprint
        log_success "Active sprint found: '#{sprint['name']}' (ID: #{sprint['id']})"
        return sprint['id']
      else
        log_warning "No active sprint found"
        display_future_sprints(board_id)
        return nil
      end
    rescue => e
      log_warning "Error searching for sprint: #{e.message}"
      log "📦 Ticket will be created in backlog"
      return nil
    end
  end

  def display_future_sprints(board_id)
    future_response = @jira_client.get("/rest/agile/1.0/board/#{board_id}/sprint?state=future")
    if future_response['values'].any?
      log "📋 Available future sprints:"
      future_response['values'].first(3).each do |s|
        log "   - #{s['name']}"
      end
      log "💡 Tip: You can start a sprint from the Jira interface"
    end
  end

  def find_sprint_field_id
    cache_key = "sprint_field_id"
    
    # Cache verification
    cached_result = cache_get(cache_key)
    if cached_result
      log "🔍 Sprint field ID found in cache"
      log "📋 Scrum board detected - sprint management enabled"
      log_success "Sprint field found: #{cached_result}"
      return cached_result
    end
    
    log "🔍 Searching for Sprint field ID..."
    log "📋 Scrum board detected - sprint management enabled"
    
    begin
      response = @jira_client.get('/rest/api/2/field')
      field = response.find { |f| f['name'] == 'Sprint' }
      
      unless field
        log_warning "Sprint field not found - board without sprints or missing configuration"
        return nil
      end
      
      log_success "Sprint field found: #{field['id']}"
      
      # Cache (direct value, not hash)
      cache_set(cache_key, field['id'])
      
      field['id']
    rescue => e
      log_warning "Error searching for Sprint field: #{e.message}"
      return nil
    end
  end

  def find_user_id(display_name)
    cache_key = "user_id_#{display_name.downcase.gsub(/\s+/, '_')}"
    
    # Cache verification
    cached_result = cache_get(cache_key)
    if cached_result
      log "🔍 User '#{display_name}' found in cache"
      if cached_result == 'not_found'  # String instead of symbol
        log_warning "User '#{display_name}' not found (cache), ticket will be unassigned"
        return nil
      else
        log_success "User found: #{cached_result['display_name']}"
        return cached_result['account_id']
      end
    end
    
    log "🔍 Searching for user '#{display_name}'..."
    
    encoded_name = URI.encode_www_form_component(display_name)
    response = @jira_client.get("/rest/api/3/user/search?query=#{encoded_name}")
    
    user = response.find { |u| u['displayName'].match(/#{Regexp.escape(display_name)}/i) }
    
    unless user
      log_warning "User '#{display_name}' not found, ticket will be unassigned"
      # Cache negative result (string)
      cache_set(cache_key, 'not_found')
      return nil
    end
    
    log_success "User found: #{user['displayName']}"
    
    # Cache with string keys
    cache_set(cache_key, { 
      'account_id' => user['accountId'], 
      'display_name' => user['displayName'] 
    })
    
    user['accountId']
  end

  def validate_issue_type(issue_type, project_key)
    cache_key = "issue_types_#{project_key}"
    
    # Cache verification
    cached_types = cache_get(cache_key)
    if cached_types
      log "🔍 Issue types for project #{project_key} found in cache"
      return find_matching_issue_type(issue_type, cached_types, project_key)
    end
    
    log "🔍 Validating issue type '#{issue_type}' for project #{project_key}..."
    
    begin
      response = @jira_client.get("/rest/api/2/issue/createmeta?projectKeys=#{project_key}&expand=projects.issuetypes")
      
      project = response['projects'].first
      unless project
        log_warning "Unable to validate issue type, using without validation"
        return issue_type
      end
      
      available_types = project['issuetypes'].map { |it| it['name'] }
      
      # Cache (array directly)
      cache_set(cache_key, available_types)
      
      return find_matching_issue_type(issue_type, available_types, project_key)
      
    rescue => e
      log_warning "Error validating issue type: #{e.message}"
      log "Using specified type without validation: #{issue_type}"
      return issue_type
    end
  end

  def find_matching_issue_type(issue_type, available_types, project_key)
    # Exact search first
    exact_match = available_types.find { |type| type.downcase == issue_type.downcase }
    return exact_match if exact_match
    
    # Partial search if no exact match
    partial_match = available_types.find { |type| type.downcase.include?(issue_type.downcase) }
    if partial_match
      log_success "Issue type found: '#{partial_match}' (partial match)"
      return partial_match
    end

    # No match found
    log_error "Issue type '#{issue_type}' not found"
    log "Available types for project #{project_key}:"
    available_types.each { |type| log "  - #{type}" }
    raise "Invalid issue type"
  end

  def create_issue(title, sprint_id, sprint_field_id, user_id, issue_type, project_key)
    log "🎫 Creating ticket..."
    
    validated_type = validate_issue_type(issue_type, project_key)
    
    payload = {
      fields: {
        project: { key: project_key },
        summary: title,
        description: "Ticket created automatically via Ruby CLI script",
        issuetype: { name: validated_type }
      }
    }
    
    if sprint_id && sprint_field_id
      payload[:fields][sprint_field_id] = sprint_id
      log "📌 Adding to active sprint"
    else
      log "📦 Creating in backlog"
    end
    
    payload[:fields][:assignee] = { id: user_id } if user_id
    
    response = @jira_client.post('/rest/api/2/issue', payload)
    response['key']
  end

  def display_success(issue_key, board_type, sprint_id)
    log_success "Ticket created successfully: #{issue_key}"
    log "🔗 URL: #{@jira_url}/browse/#{issue_key}"
    
    if board_type == 'scrum' && sprint_id.nil?
      log "📦 Ticket added to project backlog"
    elsif board_type == 'scrum' && sprint_id
      log "🏃 Ticket added to active sprint"
    else
      log "📋 Ticket added to Kanban board"
    end
    
    log ""
    log_success "🎉 Done!"
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
      log "🌐 Open manually: #{url}"
    end
  end
end