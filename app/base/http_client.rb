class HttpClient
  include AttributeInitializer
  include Utils

  attr_reader :base_url, :token

  def get(endpoint, query: nil)
    request('GET', endpoint, query:)
  end

  def post(endpoint, query: nil, body: nil)
    request('POST', endpoint, query:, body:)
  end

  def patch(endpoint, query: nil, body: nil)
    request('PATCH', endpoint, query:, body:)
  end

  def put(endpoint, query: nil, body: nil)
    request('PUT', endpoint, query:, body:)
  end

  def request(method, endpoint, body: nil, query: nil)
    uri = URI("#{base_url}#{endpoint}")
    uri.query = URI.encode_www_form(query) if query
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

    yield(request)

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      error_msg = begin
        JSON.parse(response.body)['message'] || response.message
      rescue StandardError
        response.message
      end
      # binding.pry
      raise "#{self.class} API error (#{response.code}): #{error_msg}"
    end

    JSON.parse(response.body)
  end
end
