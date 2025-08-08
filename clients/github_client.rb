module GitHub
  class Client
    BASE_URL = "https://api.github.com"

    def self.build_from_config!(config)
      token = config.github.token

      if token.nil? || token.strip.empty?
        log_error "Le paramètre de configuration 'github.token' est obligatoire"
        exit 1
      end

      new(token)
    end

    def initialize(token)
      @token = token
    end

    def create_pull_request(owner, repo, pull_request_data)
      post("/repos/#{owner}/#{repo}/pulls", pull_request_data)
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
        raise "Méthode HTTP non supportée: #{method}"
      end

      request['Authorization'] = "token #{@token}"
      request['Accept'] = 'application/vnd.github.v3+json'
      request['Content-Type'] = 'application/json'

      response = http.request(request)
      
      unless response.is_a?(Net::HTTPSuccess)
        error_msg = begin
          JSON.parse(response.body)['message'] || response.message
        rescue
          response.message
        end
        raise "Erreur GitHub API (#{response.code}): #{error_msg}"
      end

      JSON.parse(response.body)
    end
  end
end