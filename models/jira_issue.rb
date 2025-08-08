class JiraIssue 
  def initialize(raw_data)
    @raw_data = raw_data  
  end

  def key
    @raw_data["key"]
  end

  def url
    url = @raw_data["self"]
    uri = URI.parse(url)

     "#{uri.scheme}://#{uri.host}/browse/#{@raw_data["key"]}"
  end

  def title
    (@raw_data.dig('fields', 'summary') || '').gsub(/^\[.*?\]\s*/, '')
  end

  def issue_type
    @raw_data.dig('fields', 'issuetype', 'name')&.downcase || 'feat'
  end

  def description 
    @raw_data.dig('fields', 'description') || @raw_data.dig('fields', 'summary') || ''
  end

  def method_missing(method_name, *args, &block)
    key = method_name.to_s
    
    if @raw_data.key?(key)
      @raw_data[key]
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @raw_data.key?(method_name.to_s) || super
  end
end