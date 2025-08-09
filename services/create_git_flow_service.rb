require_relative 'base_service'

class CreateGitFlowService < BaseService

  attr_reader(
    :branch_name, 
    :issue_key, 
    :issue_client, 
    :git_repo_client, 
    :repo, 
    :owner,
    :create_pull_request_service_factory
  )

  def call
    git_navigate_to_repo!

    if using_current_branch?
      log_info "Using current git branch: #{branch_name}"
      check_current_branch_not_protected!
      git_commit_if_changes
    else
      git_stash_changes_if_protected_branch
      git_commit_if_changes
      if git_branch_exists?(branch_name)
        checkout_to_existing_branch 
      else 
        checkout_to_base_branch
        git_create_branch(branch_name)
      end
    end

    existing_pr = get_existing_pr
    if existing_pr
      log_info "Found existing PR ##{existing_pr['number']}: #{existing_pr['title']}"
      pr_url = existing_pr['url']
    else
      git_commit(commit_message, "--allow-empty")
      git_push_branch
      pr_url = create_pull_request
    end
    
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
    @branch_name ||= with_issue ? create_branch_name_from_issue : raise("Branch name is required when no issue is provided")
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

  def using_current_branch?
    return @using_current_branch if defined?(@using_current_branch)
    @using_current_branch = branch_name == git_current_branch
  end

  def check_current_branch_not_protected!
    return unless git_branch_protected?(branch_name)

    raise "Current branch '#{branch_name}' is protected. Please switch to another branch or create a new one."
  end

  def checkout_to_existing_branch
    log_info "Branch '#{branch_name}' already exists"
    
    yes_no(
      text: "Do you want to use the existing branch?", 
      yes: proc {
        if branch_name != git_current_branch
          log_info "Switching to existing branch '#{branch_name}'..."
          git_checkout(branch_name)
        else
          log_info "Already on branch '#{branch_name}'"
        end
      }, 
      no: proc {
        raise "Operation cancelled"
      }
    )
  end

  def checkout_to_base_branch
    main_branch = git_main_branch_name
    current_branch = git_current_branch
    
    return if main_branch == current_branch

    yes_no(
      text: "Do you want to use '#{main_branch}' as base branch or use the current branch '#{current_branch}'? (y for #{main_branch}, n for current)",
      yes: proc { 
        if current_branch != main_branch
          log_info "Switching to #{main_branch} as base branch..."
          git_checkout(main_branch) 
          git_pull
        else
          log_info "Already on #{main_branch}"
        end
      },
      no: proc {
        log_info "Using current branch '#{current_branch}' as base branch..."
      }
    )
  end

  def create_branch_name_from_issue
    prefix = issue.issue_type == 'bug' ? 'fix/' : 'feat/'
    branch_suffix = issue.title
      .downcase
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .gsub(/^-|-$/, '')
    
    branch_name = "#{prefix}#{branch_suffix}"

    log_info "Creating branch: #{branch_name}"

    branch_name
  end

  def fetch_issue
    log_info "Fetching Issue: #{issue_key}"

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
    log_info "Commit message: #{commit_message}"

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

  def get_existing_pr
    cache_get("pr_#{repo}_#{branch_name}") || git_repo_client.fetch_pull_request_by_branch_name(owner, repo, branch_name)
  end

  def create_pull_request
    create_pull_request_service_factory.call(
      title: commit_message,
      head: branch_name,
      base: git_main_branch_name,
      description:,
      issue_type:,
      git_repo_client:, 
      repo:, 
      owner:,
      issue:,
    )
  end

end