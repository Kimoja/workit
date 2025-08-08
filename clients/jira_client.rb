
require_relative 'base_client'
require_relative '../models/jira_ticket'

class JiraClient < BaseClient
  def self.build_from_config!(config)
    url = config.jira.url
    email = config.jira.email
    token = config.jira.token

    if url.nil? || token.strip.empty?
      log_error "Configuration parameter 'jira.url' is required"
      exit 1
    end

    unless url.match?(/\Ahttps?:\/\/.+\.atlassian\.net\z/)
      log_warning "Warning: Jira URL doesn't appear to be a standard Atlassian URL"
      log "Configured URL: #{url}"
    end

    if email.nil? || email.strip.empty?
      log_error "Configuration parameter 'jira.email' is required"
      exit 1
    end

    if token.nil? || token.strip.empty?
      log_error "Configuration parameter 'jira.token' is required"
      exit 1
    end

    new(url, email, token)
  end

  def initialize(url, email, token)
    super(url, Base64.strict_encode64("#{email}:#{token}"))
  end

  def fetch_ticket(key)
    map_ticket(get("/rest/api/2/issue/#{key}"))
  end

  def create_ticket(payload)
    map_ticket(post('/rest/api/2/issue', payload))
  end

  def fetch_boards
    get('/rest/agile/1.0/board')['values']
  end

  def fetch_board(board_id)
    get("/rest/agile/1.0/board/#{board_id}")
  end

  def fetch_board_configuration(board_id)
    get("/rest/agile/1.0/board/#{board_id}/configuration")
  end

  def fetch_active_sprint(board_id)
    get("/rest/agile/1.0/board/#{board_id}/sprint?state=active")['values'].first
  end

  def fetch_fields
    get('/rest/api/2/field')
  end

  def fetch_field_by_name(name)
    fetch_fields.find { |f| f['name'] == name }
  end

  def fetch_issue_types(project_key)
    project = get("/rest/api/2/issue/createmeta?projectKeys=#{project_key}&expand=projects.issuetypes")['projects'].first

    return unless project

    project['issuetypes'].map { |it| it['name'] }
  end

  def fetch_user_by_name(name)
    encoded_name = URI.encode_www_form_component(name)
    response = @jira_client.get("/rest/api/3/user/search?query=#{encoded_name}")
    
   response.find { |u| u['displayName'].match(/#{Regexp.escape(name)}/i) }
  end

  def request(method, endpoint, body = nil)
    super(method, endpoint, body) do |request|
      request['Authorization'] = "Basic #{@token}"
      request['Content-Type'] = 'application/json'
    end
  end

  def map_ticket(raw_data)
    JiraTicket.new(raw_data)
  end
end