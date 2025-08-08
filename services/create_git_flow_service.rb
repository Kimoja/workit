require_relative 'base_service'

class CreateGitFlowService < BaseService
  attr_reader :branch_name, :issue_key, :issue_client, :git_repo_client, :repo, :owner

  def call
    setup_branch_workflow
    git_commit_empty(commit_message)
    git_push_branch
    pr_url = create_pull_request
    
    open_browser(pr_url)
  end

  private

  def with_issue
    !!issue_key
  end

  def issue 
    @issue ||= with_issue ? fetch_issue : nil
  end

  def branch_name
    @branch_name ||= with_issue ? create_branch_name_from_issue : raise("Branch name is required")
  end

  def commit_message
    @commit_message ||= with_issue ? create_commit_message_from_issue : create_commit_message_from_branch_name
  end

  def description
    @description ||= with_issue ? issue.description : commit_message
  end

  def issue_type
    @issue_type ||=  with_issue ? issue.issue_type : get_issue_type_from_branch_name
  end

  def setup_branch_workflow
    git_navigate_to_repo!
    git_commit_if_changes
    # Si aucune branche, demander à l'utilisateur d'utiliser la branche actuelle
    # Sinon, demande d'utiliser master ou la branche actuelle
    if git_current_branch != git_main_branch_name
      yes_no(
        text: "Do you want to use '#{git_main_branch_name}' as base branche?", 
        yes: proc {
          git_switch_to_main_branch
        }
      )
    end

    git_create_branch(branch_name, ask_if_exists: true)
  end
  
  def create_branch_name_from_issue
    prefix = issue.issue_type == 'bug' ? 'fix/' : 'feat/'
    branch_suffix = issue.title
      .downcase
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .gsub(/^-|-$/, '')
    
    branch_name = "#{prefix}#{branch_suffix}"

    log "Creating branch: #{branch_name}"

    branch_name
  end

  def fetch_issue
    log "Fetching Issue: #{issue_key}"

    issue_client.fetch_issue(issue_key)
  end

  def create_commit_message_from_branch_name
    # Extract prefix and suffix
    if branch_name.match(/^(fix|feat|feature|bug|hotfix|chore|docs|style|refactor|test)\/(.+)$/)
      prefix = $1.upcase
      suffix = $2
      
      # Transform suffix: replace dashes with spaces and capitalize
      title = suffix.gsub('-', ' ').strip.capitalize
      
      "[#{prefix}] #{title}"
    else
      # If no recognized prefix, just transform the whole string
      branch_name.gsub('-', ' ').strip.capitalize
    end
  end

  def create_commit_message_from_issue
    type_prefix = issue.issue_type == 'bug' ? '[FIX]' : '[FEAT]'
    
    commit_message = "#{type_prefix} #{issue.key} - #{issue.title}"
    log "Commit message: #{commit_message}"

    commit_message
  end

  def get_issue_type_from_branch_name
    if branch_name.match(/^(fix|bug)\//)
      'bug'
    elsif branch_name.match(/^(bump)\//)
      'bump'
    else
      'feat'
    end
  end

  def create_pull_request
    log "Creating pull request..."
    binding.pry 
    raise
    pull_request = git_repo_client.create_pull_request(
      owner, 
      repo, 
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
    
    if with_issue && issue.key && issue.url
      template = template.gsub(/(##\s*📔?\s*[Tt]icket[^:\n]*:?)[\s\-]*(?=[^\s\-]|$)/mi, "\\1\n\n- [#{issue.key}](#{issue.url})\n\n")
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