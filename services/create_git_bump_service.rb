require_relative 'base_service'

class CreateGitBumpService < BaseService

  attr_reader(
    :branch_name, 
    :git_repo_client, 
    :repo, 
    :owner,
    :create_pull_request_service_factory
  )

  def call
    git_navigate_to_repo!
    git_stash_changes_if_protected_branch
    git_commit_if_changes
    git_checkout(git_main_branch_name)
    git_pull
    git_create_branch(branch_name)
    cherry_pick_results = cherry_pick_dependabot_commits
    description = create_description(cherry_pick_results)
    bundle_update
    yarn_update
    pr_url = create_pull_request(description)
    open_browser(pr_url)
  end

  private

  def dependabot_pull_requests
    return @dependabot_pull_requests if defined?(@dependabot_pull_requests)

    log_info "Fetching Dependabot pull requests..."

    prs = git_repo_client.fetch_open_pull_requests(owner, repo)
    
    dependabot_prs = prs.select do |pr|
      pr['user']['login'] == 'dependabot[bot]'
    end
    
    log "Found #{dependabot_prs.length} Dependabot pull requests"
    dependabot_prs.each { |pr| log "  - #{pr['title']} (#{pr['head']['ref']})" }

    @dependabot_pull_requests = dependabot_prs
  end

  def cherry_pick_dependabot_commits
    log "Cherry-picking commits from Dependabot PRs..."

    cherry_pick_results = []

    dependabot_pull_requests.each do |pr|
      branch_name = pr['head']['ref']
      pr_title = pr['title']
      
      log "\nProcessing PR: #{pr_title}"
      log "Branch: #{branch_name}"
      
      git_fetch_branch(branch_name)
      
      commits = git_repo_client.fetch_pull_request_commits(owner, repo, pr['number'])
      commit_shas = commits.map { |c| c['sha'] }
      
      log_info "Found #{commit_shas.length} commit(s) to cherry-pick"
      
      success = true
      cherry_picked_commits = []
      
      commit_shas.each do |sha|
        if git_cherry_pick(sha)
          cherry_picked_commits << sha
          log "    ✓ Success"
        else
          log "    ✗ Failed - conflicts detected"
          success = false
          break
        end
      end
      
      unless success
        log_warning "Rolling back cherry-picks for this PR due to conflicts..."
        cherry_picked_commits.reverse.each do |sha|
          git_revert(sha)
        end
      end
      
      cherry_pick_results << {
        pr: pr,
        success: success,
        commits: commit_shas,
        branch: branch_name
      }
    end
    
    log "\n"
    log_info "\nCherry-pick summary:"
    
    cherry_pick_results.each do |result|
      status = result[:success] ? "✓" : "✗"
      log "  #{status} #{result[:pr]['title']}"
    end

    cherry_pick_results
  end

  def create_description(cherry_pick_results)
    summary = "Automatic gem updates via Dependabot.\n\n"
    summary += "**Processed Dependabot branches:**\n\n"
    
    cherry_pick_results.each do |result|
      status_icon = result[:success] ? "✅" : "❌"
      status_text = result[:success] ? "Cherry-pick successful" : "Cherry-pick failed (conflicts)"
      
      # Add link to PR
      pr_link = "[##{result[:pr]['number']}](#{result[:pr]['html_url']})"
      
      summary += "- #{status_icon} `#{result[:branch]}` - #{result[:pr]['title']} #{pr_link} (#{status_text})\n"
      
      # If failed, add SHA1 of commits to apply manually
      unless result[:success]
        binding.pry
        summary += "  - **Commits to apply manually:**\n"
        result[:commits].each do |sha|
          commit_short = sha[0..7]
          commit_link = git_repo_client.build_commit_url(owner, repo, sha)
          summary += "    - `git cherry-pick #{commit_short}` -> [`#{commit_short}`](#{commit_link})\n"
        end
      end
    end
    
    if cherry_pick_results.any? { |r| !r[:success] }
      summary += "\n⚠️ **Note:** Some cherry-picks failed due to conflicts. "
      summary += "These changes will need to be applied manually using the commit links above.\n"
    end
    
    summary
  end

  def bundle_update
    log_info "Running bundle update --all..."
    
    result = system("bundle update --all")
    
    unless result
      raise "Bundle update failed"
    end
    
    log_success "Bundle update completed successfully"
    
    git_commit_if_changes("Update gems via bundle update (#{Time.now.strftime('%Y-%m-%d')})")
  end
  

  def yarn_update
    log_info "Running yarn upgrade --all..."
    
    result = system("yarn upgrade")
    
    unless result
      raise "Yarn upgrade failed"
    end
    
    log_success "Yarn upgrade completed successfully"
    
    git_commit_if_changes("Update js dependencies via yarn upgrade (#{Time.now.strftime('%Y-%m-%d')})")
  end

  def create_pull_request(description)

    binding.pry 
    raise
    
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