class CreateGitFlowService
  def initialize(branch_name:, jira_ticket:, jira_client:, github_client:)
    @branch_name = branch_name
    @jira_ticket = jira_ticket
    @jira_client = jira_client
    @github_client = github_client
    @with_ticket = jira_ticket
  end

  def call
    summary

    git_navigate_to_repo!
    git_commit_if_changes
    git_switch_to_main_branch

    git_create_branch(branch_name, ask_if_exists: true)
    git_commit_empty(commit_message)
    git_push_branch
    pr_url = create_pull_request
    
    open_browser(pr_url)
  end

  private

  def summary
    log "🚀 Creating Git branch and GitHub pull request"
    log "Branch name: #{@branch_name}"
    log "Jira ticket: #{@jira_ticket}"
    log ""
  end

  def ticket 
    @ticket ||= @with_ticket ? fetch_jira_ticket : nil
  end

  def branch_name
    @branch_name ||= @with_ticket ? create_branch_name_from_ticket : raise("Branch name is required")
  end

  def commit_message
    @commit_message ||= @with_ticket ? create_commit_message_from_ticket : create_commit_message_from_branch_name
  end

  def description
    @description ||= @with_ticket ? ticket.description : commit_message
  end

  def github_repo_info
    @github_repo_info ||= git_repo_info
  end

  def issue_type
    @issue_type ||=  @with_ticket ? ticket.issue_type : get_issue_type_from_branch_name
  end

  def create_branch_name_from_ticket
    prefix = ticket.issue_type == 'bug' ? 'fix/' : 'feat/'
    branch_suffix = ticket.title
      .downcase
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .gsub(/^-|-$/, '')
    
    branch_name = "#{prefix}#{branch_suffix}"

    log "Creating branch: #{branch_name}"

    branch_name
  end

  def fetch_jira_ticket
    log "Fetching Jira ticket: #{@jira_ticket}"

    @jira_client.fetch_ticket(@jira_ticket)
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

  def create_commit_message_from_ticket
    type_prefix = ticket.issue_type == 'bug' ? '[FIX]' : '[FEAT]'
    
    commit_message = "#{type_prefix} #{ticket.key} - #{ticket.title}"
    log "Commit message: #{commit_message}"

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

  def create_pull_request
    log "Creating pull request..."

    pull_request = @github_client.create_pull_request(
      github_repo_info[:owner], 
      github_repo_info[:repo], 
      {
        title: commit_message,
        head: branch_name,
        base: git_main_branch_name,
        body: prepare_pr_description
      }
    )

    url = pull_request['html_url']
    log "Pull request created successfully: #{url}"

    url
  rescue => e
    log_error "Creating pull request: #{e.message}"
    exit 1
  end

  def prepare_pr_description
    template = fetch_pr_template
    
    if issue_type == 'bug'
      template = template.gsub(/- \[ \] [Bb]ug/, '- [x] Bug fix')
    elsif issue_type == 'bump'
      template = template.gsub(/- \[ \] .*?(gems|dependancies|dépendance).*?$/, '- [x] Mise à jour de gems')
    else
      template = template.gsub(/- \[ \] [Nn]ouvelle/, '- [x] Nouvelle fonctionnalité')
    end
    
    if @with_ticket && ticket.key && ticket.url
      template = template.gsub(/(##\s*📔?\s*[Tt]icket[^:\n]*:?)[\s\-]*(?=[^\s\-]|$)/mi, "\\1\n\n- [#{ticket.key}](#{ticket.url})\n\n")
    end
    
    if description
      clean_description = description.gsub(/\{[^}]+\}/, '').strip
      template = template.gsub(/(##\s*📓?\s*[Dd]escription[^:\n]*:?)[\s\-]*(?=[^\s\-]|$)/mi, "\\1\n\n#{clean_description}\n\n")
    end
    
    template
  end

  def fetch_pr_template
    log "Fetching pull request template from local file..."
    
    template_path = File.join(Dir.pwd, 'pull_request_template.md')
    
    if File.exist?(template_path)
      log "Found PR template at: #{template_path}"
      File.read(template_path)
    else
      log "Warning: Could not find PR template at #{template_path}, using default template"
      get_default_template
    end
  rescue => e
    log_error "Reading PR template file: #{e.message}"
    log "Using default template instead"
    get_default_template
  end
  
  def get_default_template
    default_template_path = File.join(Dir.pwd, 'resources', 'default_pull_request_template.md')
    
    if File.exist?(default_template_path)
      log "Using default template from: #{default_template_path}"
      File.read(default_template_path)
    else
      log_warning "Default template not found at #{default_template_path}, using fallback template"
      get_fallback_template
    end
  rescue => e
    log_error "Reading default template file: #{e.message}"
    log "Using fallback template instead"
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