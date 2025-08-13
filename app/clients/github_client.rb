module Clients
  class GithubClient < Client
    BASE_URL = 'https://api.github.com'

    def self.build_from_config!
      token = Config.get('github', 'token')

      raise "Configuration parameter 'github.token' is required" if token.nil? || token.strip.empty?

      new(token:)
    end

    def initialize(token:)
      super(base_url: BASE_URL, token:)
    end

    def create_pull_request(owner, repo, pull_request_data)
      pr = post("/repos/#{owner}/#{repo}/pulls", body: pull_request_data)
      add_pull_request_to_cache(pr, owner, repo)
    end

    def fetch_pull_request_commits(owner, repo, pr_number)
      get("/repos/#{owner}/#{repo}/pulls/#{pr_number}/commits")
    end

    def fetch_pull_request_by_branch_name(owner, repo, branch_name)
      cached_pr = Cache.get("prs", "github", owner, repo, branch_name)
      return cached_pr if cached_pr

      query = URI.encode_www_form({ head: "#{owner}:#{branch_name}" })
      pr = get("/repos/#{owner}/#{repo}/pulls", query:).first

      add_pull_request_to_cache(pr, owner, repo) if pr
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

    private

    def add_pull_request_to_cache(pull_request, owner, repo)
      Cache.set(
        "prs", "github", owner, repo, pull_request['head']['ref'],
        value: {
          url: pr['html_url'],
          number: pr['number'],
          title: pr['title']
        }
      )
    end
  end
end
