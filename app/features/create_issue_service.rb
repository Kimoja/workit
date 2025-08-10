

class CreateIssueService < Callable
  include AttributeInitializer

  attr_reader :title, :board_name, :issue_type, :assignee_name, :issue_client

  def call
    issue = create_issue
    add_to_cache(issue)
    display_success(issue)
    open_browser(issue.url)
  end

  private

  def board_id
    @board_id ||= find_board_id
  end

  def board_info
    @board_id ||= find_board_info
  end

  def board_type
    @project_key ||= board_info['type']
  end

  def project_key
    @project_key ||= board_info['project_key']
  end

  def sprint_field_id
    @sprint_field_id ||= board_type == 'scrum' ? find_sprint_field_id : nil
  end

  def sprint_id
    @sprint_id ||= board_type == 'scrum' ? find_active_sprint : nil
  end

  def user_id
    @user_id ||= find_user_id
  end
  
  def find_board_id
    cache_key = "board_id_#{board_name.downcase.gsub(/\s+/, '_')}"
    
    cached_result = cache_get(cache_key)
    if cached_result
      log "🔍 Board '#{board_name}' found in cache"
      log_success "Board found: ID #{cached_result['id']} (Type: #{cached_result['type']})"
      return cached_result['id']
    end
    
    log "🔍 Searching for board '#{board_name}'..."

    boards = issue_client.fetch_boards
    board = boards.find { |b| b['name'].match(/#{Regexp.escape(board_name)}/i) }
    
    unless board
      log_error "Board '#{board_name}' not found"
      log "Available boards:"
      boards.each { |b| log "  - #{b['name']} (#{b['type']})" }
      raise
    end
    
    log_success "Board found: ID #{board['id']} (Type: #{board['type']})"
    
    cache_set(cache_key, { 
      'id' => board['id'], 
      'type' => board['type'] 
    })
    
    board['id']
  end

  def find_board_info
    cache_key = "board_info_#{board_id}"
    
    cached_result = cache_get(cache_key)
    if cached_result
      log "🔍 Board information found in cache"
      log_success "Board type: #{cached_result['type']}"
      log_success "Associated project: #{cached_result['project_key']}"
      return cached_result
    end
    
    log "🔍 Retrieving board information..."
    
    board = issue_client.fetch_board(board_id)
    board_type = board['type'].downcase
    project_key = extract_project_key(board_id, board)
    
    unless project_key
      raise "Unable to determine project associated with board"
    end
    
    log_success "Board type: #{board_type}"
    log_success "Associated project: #{project_key}"
    
    result = {
      'type' => board_type,
      'project_key' => project_key
    }
    
    cache_set(cache_key, result)
    
    result
  end

  def extract_project_key(board_id, board)
    # Method 1: Directly from board information
    if board['location'] && board['location']['projectKey']
      return board['location']['projectKey']
    end

    # Method 2: Via board configuration
    begin
      board_configuration = issue_client.fetch_board_configuration(board_id)
      if board_configuration['location'] && board_configuration['location']['projectKey']
        return board_configuration['location']['projectKey']
      end
    rescue => e
      log_warning "Unable to retrieve board configuration: #{e.message}"
    end
    
    nil
  end

  def find_active_sprint
    log_info "🔍 Searching for active sprint..."

    active_sprint = issue_client.fetch_active_sprint(board_id)

    if active_sprint
      log_success "Active sprint found: '#{active_sprint['name']}' (ID: #{active_sprint['id']})"
      return active_sprint['id']
    end
  
    log_warning "No active sprint found"
    return nil

  rescue => e
    log_warning "Error searching for sprint: #{e.message}"
    log "📦 Issue will be created in backlog"
    return nil
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
      field = issue_client.fetch_field_by_name('Sprint')
      
      unless field
        log_warning "Sprint field not found - board without sprints or missing configuration"
        return nil
      end
      
      log_success "Sprint field found: #{field['id']}"
      
      cache_set(cache_key, field['id'])
    rescue => e
      log_warning "Error searching for Sprint field: #{e.message}"
      return nil
    end
  end

  def find_user_id
    cache_key = "user_id_#{assignee_name.downcase.gsub(/\s+/, '_')}"
    
    # Cache verification
    cached_result = cache_get(cache_key)
    if cached_result
      log "🔍 User '#{assignee_name}' found in cache"
      if cached_result == 'not_found'  # String instead of symbol
        log_warning "User '#{assignee_name}' not found (cache), issue will be unassigned"
        return nil
      else
        log_success "User found: #{cached_result['display_name']}"
        return cached_result['account_id']
      end
    end
    
    log "🔍 Searching for user '#{assignee_name}'..."
    
    user = issue_client.fetch_user_by_name(assignee_name)
    
    unless user
      log_warning "User '#{assignee_name}' not found, issue will be unassigned"
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

  def validate_issue_type
    cache_key = "issue_types_#{project_key}"
    
    # Cache verification
    cached_types = cache_get(cache_key)
    if cached_types
      log "🔍 Issue types for project #{project_key} found in cache"
      return find_matching_issue_type(cached_types)
    end
    
    log "🔍 Validating issue type '#{issue_type}' for project #{project_key}..."
    
    begin
      issue_types = issue_client.fetch_issue_types(project_key)
      
      unless issue_types
        log_warning "Unable to validate issue type, using without validation"
        return issue_type
      end
      
      cache_set(cache_key, issue_types)
      
      return find_matching_issue_type(issue_types)
    rescue => e
      log_warning "Error validating issue type: #{e.message}"
      log "Using specified type without validation: #{issue_type}"
      return issue_type
    end
  end

  def find_matching_issue_type(available_types)
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

  def create_issue
    log "🎫 Creating issue..."
    
    validated_type = validate_issue_type
    
    payload = {
      fields: {
        project: { key: project_key },
        summary: title,
        description: "Issue created automatically via Ruby CLI script",
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
    
    binding.pry 
    raise
    
    issue_client.create_issue(payload)
  end

  def add_to_cache(issue)
    cache_set("last_issue", { 
      'url' => issue.url, 
      'issue_key' => issue.key 
    })
  end

  def display_success(issue)
    log_success "Issue created successfully: #{issue.key}"
    log "🔗 URL: #{issue.url}"
    
    if board_type == 'scrum' && sprint_id.nil?
      log "📦 Issue added to project backlog"
    elsif board_type == 'scrum' && sprint_id
      log "🏃 Issue added to active sprint"
    else
      log "📋 Issue added to Kanban board"
    end
    
    log ""
    log_success "🎉 Done!"
  end
end