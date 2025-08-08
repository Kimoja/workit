class CreateGitBranchService
  def initialize(branch_name:, jira_ticket:, jira_client:, github_client:)
    @branch_name = branch_name
    @jira_ticket = jira_ticket
    @jira_client = jira_client
    @github_client = github_client
  end

  def call
    summary

    git_navigate_to_repo!
    git_commit_if_changes
    git_switch_to_main_branch

    github_repo = git_get_github_repo_info

    if @branch_name
      branch_name = @branch_name
      commit_message = create_commit_message_from_branch_name
      issue_type = get_issue_type_from_branch_name
      description = commit_message
      ticket_key = nil
      jira_link = nil
    else
      ticket = fetch_jira_ticket
      branch_name = create_branch_name_from_ticket(ticket)
      commit_message = create_commit_message_from_ticket(ticket)
      issue_type = ticket.issue_type
      ticket_key = ticket.key
      description = ticket.description
      jira_link = ticket.url
    end
    binding.pry 
    raise 
    git_create_branch(branch_name, ask_if_exists: true)
    create_empty_commit(commit_message)
    git_push_branch
    
    pr_url = create_pull_request(
      github_repo:, 
      title: commit_message, 
      issue_type:, 
      ticket_key:, 
      jira_link:, 
      description:
    )
    
    open_browser(pr_url)
  end

  private

  def summary
    log "🚀 Creating Git branch and GitHub pull request"
    log "Branch name: #{@branch_name}"
    log "Jira ticket: #{@jira_ticket}"
    log ""
  end

  def fetch_jira_ticket
    puts "Fetching Jira ticket: #{@jira_ticket}"

    @jira_client.fetch_ticket(@jira_ticket)
  end

  def create_branch_name_from_ticket(ticket)
    prefix = ticket.issue_type == 'bug' ? 'fix/' : 'feat/'
    branch_suffix = ticket.title
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

  def create_commit_message_from_ticket(ticket)
    type_prefix = ticket.issue_type == 'bug' ? '[FIX]' : '[FEAT]'
    
    commit_message = "#{type_prefix} #{ticket.key} - #{ticket.title}"
    puts "Commit message: #{commit_message}"

    commit_message
  end

  def get_issue_type_from_branch_name
    if @branch_name.match(/^(fix|bug)\//)
      'bug'
    elsif @branch_name.match(/^(bump)\//)
      'bump'
    else
      'feat'
    end
  end

  def create_pull_request(github_repo:, title:, issue_type:, ticket_key:, jira_link:, description:)
    puts "Creating pull request..."
    
    current_branch = `git branch --show-current`.strip
    base_branch = git_main_branch_name
    
    pr_description = prepare_pr_description(
      issue_type:, 
      ticket_key:, 
      jira_link:, 
      description:
    )
    
    pr_data = {
      title: title,
      head: current_branch,
      base: base_branch,
      body: pr_description
    }
    
    @github_client.create_pull_request(github_repo[:owner], github_repo[:repo], pr_data)

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
    elsif issue_type == 'bump'
      template = template.gsub(/- \[ \] .*?(gems|dependancies|dépendance).*?$/, '- [x] Mise à jour de gems')
    else
      template = template.gsub(/- \[ \] [Nn]ouvelle/, '- [x] Nouvelle fonctionnalité')
    end
    
    if ticket_key && jira_link
      template = template.gsub(/(##\s*📔?\s*[Tt]icket[^:\n]*:?)[\s\-]*(?=[^\s\-]|$)/mi, "\\1\n\n- [#{ticket_key}](#{jira_link})\n\n")
    end
    
    if description
      clean_description = description.gsub(/\{[^}]+\}/, '').strip
      template = template.gsub(/(##\s*📓?\s*[Dd]escription[^:\n]*:?)[\s\-]*(?=[^\s\-]|$)/mi, "\\1\n\n#{clean_description}\n\n")
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