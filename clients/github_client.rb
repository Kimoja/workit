
require_relative 'base_client'

class GithubClient < BaseClient

  BASE_URL = "https://api.github.com"
  
  def initialize(token)
    super(BASE_URL, token)
  end

  def self.build_from_config!(config)
    token = config.github.token

    if token.nil? || token.strip.empty?
      log_error "Configuration parameter 'github.token' is required"
      exit 1
    end

    new(token)
  end

  def create_pull_request(owner, repo, pull_request_data)
    post("/repos/#{owner}/#{repo}/pulls", pull_request_data)
  end

  def request(method, endpoint, body = nil)
    super(method, endpoint, body) do |request|
      request['Authorization'] = "token #{@token}"
      request['Accept'] = 'application/vnd.github.v3+json'
      request['Content-Type'] = 'application/json'
    end
  end
end