
class JiraClient
  BASE_URL = "https://cheerz0.atlassian.net"

  def self.build_from_config!(config)
    email = config.jira.email
    token = config.jira.token

    if email.nil? || email.strip.empty?
      log_error "Configuration parameter 'jira.email' is required"
      exit 1
    end

    if token.nil? || token.strip.empty?
      log_error "Configuration parameter 'jira.token' is required"
      exit 1
    end

    new(email, token)
  end

  def initialize(email, token)
    @email = email
    @token = token
  end

  def get(endpoint)
    request('GET', endpoint)
  end

  def post(endpoint, body = nil)
    request('POST', endpoint, body)
  end

  private

  def request(method, endpoint, body = nil)
    uri = URI("#{BASE_URL}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
      request.body = body.to_json if body
    else
      raise "Unsupported HTTP method: #{method}"
    end

    auth_string = Base64.strict_encode64("#{@email}:#{@token}")
    request['Authorization'] = "Basic #{auth_string}"
    request['Content-Type'] = 'application/json'

    response = http.request(request)
    
    unless response.is_a?(Net::HTTPSuccess)
      error_msg = begin
        JSON.parse(response.body)['errorMessages']&.join(', ') || response.message
      rescue
        response.message
      end
      raise "API error (#{response.code}): #{error_msg}"
    end

    JSON.parse(response.body)
  end
end