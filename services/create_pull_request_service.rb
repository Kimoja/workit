require_relative 'base_service'

class CreatePullRequestService < BaseService

  attr_reader(
    :title,
    :head,
    :base,
    :description,
    :issue_type,
    :git_repo_client, 
    :repo, 
    :owner,
    :issue
  )

  def call
    log "Creating pull request..."
    binding.pry 
    #raise
    pull_request = git_repo_client.create_pull_request(
      owner, 
      repo, 
      {
        title:,
        head:,
        base:,
        body: prepare_pr_description
      }
    )

    url = pull_request['html_url']
    log "Pull request created successfully: #{url}"

    url
  end

  private

  def prepare_pr_description
    template = fetch_pr_template
    
    if issue_type == 'bug'
      template = template.gsub(/- \[ \] [Bb]ug/, '- [x] Bug fix')
    elsif issue_type == 'bump'
      template = template.gsub(/- \[ \] .*?(gems|dependancies|dépendance).*?$/, '- [x] Mise à jour de gems')
    else
      template = template.gsub(/- \[ \] [Nn]ouvelle/, '- [x] Nouvelle fonctionnalité')
    end
    
    if issue && issue.key && issue.url
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