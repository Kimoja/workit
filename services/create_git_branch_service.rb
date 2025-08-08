class CreateGitBranchService
  def initialize(branch_name:, jira_ticket:, jira_client:, github_client:)
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

    if @branch_name
      branch_name = @branch_name
      commit_message = create_commit_message_from_branch_name
      issue_type = get_issue_type_from_branch_name
      description = commit_message
      ticket_key = nil
      jira_link = nil
      ticket_data = nil
    else
      ticket_data = fetch_jira_ticket
      branch_name = create_branch_name_from_ticket(ticket_data)
      commit_message = create_commit_message_from_ticket(ticket_data)
      issue_type = get_issue_type_from_ticket(ticket_data)
      ticket_key = get_ticket_key
      description = get_ticket_description(ticket_data)
      jira_link = get_jira_link(ticket_data, ticket_key)
    end

    git_create_branch(branch_name)
    create_empty_commit(commit_message)
    git_push_branch
    
    pr_url = create_pull_request(
      github_repo:, 
      commit_message:, 
      issue_type:, 
      ticket_key:, 
      jira_link:, 
      description:
    )
    
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

  def create_branch_name_from_ticket(ticket_data)
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

  def create_commit_message_from_branch_name
    # Extract prefix and suffix
    if @branch_name.match(/^(fix|feat|feature|bug|hotfix|chore|docs|style|refactor|test)\/(.+)$/)
      prefix = $1.upcase
      suffix = $2
      
      # Transform suffix: replace dashes with spaces and capitalize
      title = suffix.gsub('-', ' ').strip.capitalize
      
      "[#{prefix}] #{title}"
    else
      # If no recognized prefix, just transform the whole string
      @branch_name.gsub('-', ' ').strip.capitalize
    end
  end

  def create_commit_message_from_ticket(ticket_data)
    issue_type = ticket_data.dig('fields', 'issuetype', 'name')&.downcase
    title = (ticket_data.dig('fields', 'summary') || '').gsub(/^\[.*?\]\s*/, '')
    ticket_key = @jira_ticket.upcase
    
    # Determine type prefix
    type_prefix = issue_type == 'bug' ? '[FIX]' : '[FEAT]'
    
    commit_message = "#{type_prefix} #{ticket_key} - #{title}"
    puts "Commit message: #{commit_message}"
    commit_message
  end

  def get_issue_type_from_branch_name
    if @branch_name.match(/^(fix|bug)\//)
      'bug'
    else
      'feature'
    end
  end

  def get_issue_type_from_ticket(ticket_data)
    ticket_data.dig('fields', 'issuetype', 'name')&.downcase || 'feature'
  end

  def get_ticket_key
    @jira_ticket&.upcase
  end

  def get_ticket_description(ticket_data)
    ticket_data.dig('fields', 'description') || ticket_data.dig('fields', 'summary') || ''
  end

  def get_jira_link(ticket_data, ticket_key)
    return nil unless ticket_data

    url = ticket_data["self"]
    uri = URI.parse(url)

     "#{uri.scheme}://#{uri.host}/browse/#{ticket_key}"
  end

  def create_empty_commit(message)
    puts "Creating empty commit..."
    system("git commit --allow-empty -m '#{message}'") || raise('Failed to create empty commit')
  end

  def create_pull_request(github_repo:, commit_message:, issue_type:, ticket_key:, jira_link:, description:)
    puts "Creating pull request..."
    
    current_branch = `git branch --show-current`.strip
    base_branch = git_head_branch_name
    
    pr_description = prepare_pr_description(
      issue_type:, 
      ticket_key:, 
      jira_link:, 
      description:
    )
    
    pr_data = {
      title: commit_message,
      head: current_branch,
      base: base_branch,
      body: pr_description
    }
    
    response = @github_client.create_pull_request(github_repo[:owner], github_repo[:repo], pr_data)
    
    puts "Pull request created successfully: #{response['html_url']}"
    response['html_url']
  rescue => e
    puts "Error creating pull request: #{e.message}"
    exit 1
  end

  def prepare_pr_description(issue_type:, ticket_key:, jira_link:, description:)
    template = fetch_pr_template
    
    if issue_type == 'bug'
      template = template.gsub(/- \[ \] [Bb]ug/, '- [x] Bug fix')
    else
      template = template.gsub(/- \[ \] [Nn]ouvelle/, '- [x] Nouvelle fonctionnalité')
    end
    
    if ticket_key && jira_link
      template = template.gsub(/(##\s*📔\s*[Tt]icket[^:\n]*:?)[\s\-]*(?=[^\s\-]|$)/mi, "\\1\n\n- [#{ticket_key}](#{jira_link})\n\n")
    end
    
    if description
      clean_description = description.gsub(/\{[^}]+\}/, '').strip
      template = template.gsub(/(##\s*📓\s*[Dd]escription[^:\n]*:?)[\s\-]*(?=[^\s\-]|$)/mi, "\\1\n\n#{clean_description}\n\n")
    end
    
    template
  end

  def fetch_pr_template
    puts "Fetching pull request template from local file..."
    
    template_path = File.join(Dir.pwd, 'pull_request_template.md')
    
    if File.exist?(template_path)
      puts "Found PR template at: #{template_path}"
      File.read(template_path)
    else
      puts "Warning: Could not find PR template at #{template_path}, using default template"
      get_default_template
    end
  rescue => e
    puts "Error reading PR template file: #{e.message}"
    puts "Using default template instead"
    get_default_template
  end
  
  def get_default_template
    default_template_path = File.join(Dir.pwd, 'resources', 'default_pull_request_template.md')
    
    if File.exist?(default_template_path)
      puts "Using default template from: #{default_template_path}"
      File.read(default_template_path)
    else
      puts "Warning: Default template not found at #{default_template_path}, using fallback template"
      get_fallback_template
    end
  rescue => e
    puts "Error reading default template file: #{e.message}"
    puts "Using fallback template instead"
    get_fallback_template
  end
  
  def get_fallback_template
    <<~TEMPLATE
      ## Description
      Brief description of the changes made.

      ## Changes
      - List of changes

      ## Testing
      How was this tested?

      ## Notes
      Any additional notes or considerations.
    TEMPLATE
  end
end