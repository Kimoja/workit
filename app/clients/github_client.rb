module Clients
  class GithubClient < Client
    BASE_URL = 'https://api.github.com'

    def self.build_from_config!
      token = Config.get('github.token')

      raise "Configuration parameter 'github.token' is required" if token.nil? || token.strip.empty?

      new(token:)
    end

    def initialize(token:)
      super(base_url: BASE_URL, token:)
    end

    def fetch_open_pull_requests(owner, repo)
      prs = get("/repos/#{owner}/#{repo}/pulls?state=open")
      prs.each do |pr|
        Cache.set(
          "prs", "github", owner, repo, pr['head']['ref'], value: {
            url: pr['html_url'],
            number: pr['number'],
            title: pr['title']
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
      super do |request|
        request['Authorization'] = "token #{token}"
        request['Accept'] = 'application/vnd.github.v3+json'
        request['Content-Type'] = 'application/json'
      end
    end
  end
end
