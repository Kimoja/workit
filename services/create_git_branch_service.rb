
class CreateGitBranchService
  def initialize(branch_name:, jira_ticket:,  jira_client:, github_client:)
    @branch_name = branch_name
    @jira_ticket = jira_ticket
    @jira_client = jira_client
    @github_client = github_client
  end

  def call
    display_info
    git_find_repo
    github_repo = init_github_repo_info
    git_commit_if_changes
    git_switch_to_head_branch

    binding.pry
    raise
    if @branch_name
      branch_name = @branch_name
      commit_message = branch_name
    else
      ticket_data = fetch_jira_ticket
      branch_name = git_create_branch_name_from_jira_ticket(ticket_data)
      commit_message = create_commit_message_from_jira_ticket(ticket_data)
    end

    git_create_branch(branch_name)
    create_empty_commit(commit_message)

    git_push_branch
    pr_url = create_pull_request(github_repo, ticket_data, commit_message)
    open_in_browser(pr_url)
  end

  private

  def display_info
    log "🚀 Creating Git branch and GitHub pull request"
    log "Branch name: #{@branch_name}"
    log "Jira ticket: #{@jira_ticket}"
    log ""
  end

  def init_github_repo_info
    # Get GitHub repo URL from remote origin
    remote_url = `git config --get remote.origin.url`.strip
    
    # Parse URL to extract owner/repo
    if remote_url.match(/github\.com[\/:](.+)\/(.+)\.git$/)
      owner = $1
      repo = $2
      { owner: owner, repo: repo }
    else
      raise "Unable to parse GitHub repository information from remote URL: #{remote_url}"
    end
  end

  def fetch_jira_ticket
    puts "Fetching Jira ticket: #{@jira_ticket}"
    
    @jira_client.get("/rest/api/2/issue/#{@jira_ticket}")
  end

  def git_create_branch_name_from_jira_ticket(ticket_data)
    issue_type = ticket_data.dig('fields', 'issuetype', 'name')&.downcase
    title = ticket_data.dig('fields', 'summary') || ''
    
    # Determine prefix
    prefix = issue_type == 'bug' ? 'fix/' : 'feat/'
    
    # Remove bracket prefix if present
    clean_title = title.gsub(/^\[.*?\]\s*/, '')
    
    # Convert to lowercase, replace spaces with dashes, remove extra dashes
    branch_suffix = clean_title
      .downcase
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .gsub(/^-|-$/, '')
    
    branch_name = "#{prefix}#{branch_suffix}"
    puts "Creating branch: #{branch_name}"
    branch_name
  end 

  def create_commit_message_from_jira_ticket(ticket_data)
    issue_type = ticket_data.dig('fields', 'issuetype', 'name')&.downcase
    title = (ticket_data.dig('fields', 'summary') || '').gsub(/^\[.*?\]\s*/, '')
    ticket_key = @jira_ticket.upcase
    
    # Determine type prefix
    type_prefix = issue_type == 'bug' ? '[FIX]' : '[FEAT]'
    
    commit_message = "#{type_prefix} #{ticket_key} - #{title}"
    puts "Commit message: #{commit_message}"
    commit_message
  end

  def create_empty_commit(message)
    puts "Creating empty commit..."
    system("git commit --allow-empty -m '#{message}'") || raise('Failed to create empty commit')
  end

  def create_pull_request(ticket_data, commit_message)
    puts "Creating pull request..."
    
    # Get current branch
    current_branch = `git branch --show-current`.strip
    base_branch = 'master' # or 'main' depending on your repo
    
    pr_description = prepare_pr_description(ticket_data)
    
    pr_data = {
      title: commit_message,
      head: current_branch,
      base: base_branch,
      body: pr_description
    }
    
    uri = URI("https://api.github.com/repos/#{@github_repo[:owner]}/#{@github_repo[:repo]}/pulls")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "token #{@github_token}"
    request['Accept'] = 'application/vnd.github.v3+json'
    request['Content-Type'] = 'application/json'
    request.body = pr_data.to_json
    
    response = http.request(request)
    
    if response.code == '201'
      pr_response = JSON.parse(response.body)
      puts "Pull request created successfully: #{pr_response['html_url']}"
      pr_response['html_url']
    else
      puts "Error creating pull request: #{response.code} - #{response.body}"
      exit 1
    end
  end

  def open_pull_request_in_browser(pr_url)
    puts "Opening pull request in browser..."
    
    case RUBY_PLATFORM
    when /darwin/ # macOS
      system("open '#{pr_url}'")
    when /linux/
      system("xdg-open '#{pr_url}'")
    when /mswin|mingw|cygwin/ # Windows
      system("start '#{pr_url}'")
    else
      puts "Please open the following URL in your browser: #{pr_url}"
    end
  end

end