module Clients
  module GitRepositories
    class GithubClient < HttpClient
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
        Log.info "Creating Pull Request..."
        post("/repos/#{owner}/#{repo}/pulls", body: pull_request_data)
      end

      def reopen_pull_request(owner, repo, pr_number)
        Log.info "Reopening Pull Request ##{pr_number}..."

        body = { state: 'open' }
        pr = patch("/repos/#{owner}/#{repo}/pulls/#{pr_number}", body: body)

        if pr && pr['state'] == 'open'
          Log.info "Pull Request ##{pr_number} reopened successfully"
          return pr
        end

        Log.error "Failed to reopen Pull Request ##{pr_number}"
      end

      def fetch_pull_request_commits(owner, repo, pr_number)
        get("/repos/#{owner}/#{repo}/pulls/#{pr_number}/commits")
      end

      def fetch_pull_request_by_branch_name(owner, repo, branch_name)
        Log.info "Searching for Pull Request on branch '#{branch_name}'"

        query = { head: "#{owner}:#{branch_name}" }
        pr = get("/repos/#{owner}/#{repo}/pulls", query:).first

        if pr
          Log.info "Pull Request ##{pr['number']} found for branch '#{branch_name}'"
        else
          Log.info "No Pull Request found for branch '#{branch_name}'"
        end

        pr
      end

      def build_commit_url(owner, repo, sha)
        "https://github.com/#{owner}/#{repo}/commit/#{sha}"
      end

      def request(method, endpoint, body: nil, query: nil)
        super do |request|
          request['Authorization'] = "token #{token}"
          request['Accept'] = 'application/vnd.github.v3+json'
          request['Content-Type'] = 'application/json'
        end
      end
    end
  end
end
