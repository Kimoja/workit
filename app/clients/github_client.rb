class GithubClient < Client

  BASE_URL = "https://api.github.com"
  
  def initialize(token)
    super(BASE_URL, token)
  end

  def self.build_from_config!(config)
    token = config.github.token

    if token.nil? || token.strip.empty?
      raise "Configuration parameter 'github.token' is required"
    end

    new(token)
  end

  def fetch_open_pull_requests(owner, repo)
    prs = get("/repos/#{owner}/#{repo}/pulls?state=open")
    prs.each do |pr|
      cache_set(
        "pr_#{repo}_#{pr["head"]["ref"]}", 
        {
          url: pr['html_url'],
          number: pr['number'],
          title: pr['title'],
        }
      )
    end
  end

  def create_pull_request(owner, repo, pull_request_data)
    post("/repos/#{owner}/#{repo}/pulls", pull_request_data)
  end

  def fetch_pull_request_commits(owner, repo, pr_number)
    get("/repos/#{owner}/#{repo}/pulls/#{pr_number}/commits")
  end

  def fetch_pull_request_by_branch_name(owner, repo, branch_name)
    prs = fetch_open_pull_requests(owner, repo)
    
    prs.find { |pull_request| pull_request['head']['ref'] == branch_name }
  end

  def build_commit_url(owner, repo, sha)
    "https://github.com/#{owner}/#{repo}/commit/#{sha}"
  end

  def request(method, endpoint, body = nil)
    super(method, endpoint, body) do |request|
      request['Authorization'] = "token #{@token}"
      request['Accept'] = 'application/vnd.github.v3+json'
      request['Content-Type'] = 'application/json'
    end
  end
end