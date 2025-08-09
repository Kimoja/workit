
class BaseClient
  def initialize(base_url, token)
    @base_url = base_url
    @token = token
  end

  def get(endpoint)
    request('GET', endpoint)
  end

  def post(endpoint, body = nil)
    request('POST', endpoint, body)
  end

  def request(method, endpoint, body = nil)
    uri = URI("#{@base_url}#{endpoint}")
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
      rescue
        response.message
      end
      binding.pry 
      raise "#{self.class} API error (#{response.code}): #{error_msg}"
    end

    JSON.parse(response.body)
  end
end