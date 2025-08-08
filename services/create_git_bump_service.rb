require_relative 'base_service'

class CreateGitBumpService < BaseService
  def call
    summary
    git_navigate_to_repo!
    github_repo = init_github_repo_info
    git_commit_if_changes
    git_switch_to_main_branch
    git_create_branch(@branch_name, ask_if_exists: true)

    binding.pry 
    raise 

    prs = get_dependabot_pull_requests(github_repo)
    cherry_pick_dependabot_commits(prs)

    create_empty_commit(commit_message)
    git_push_branch
    
    pr_url = create_pull_request(
      github_repo:, 
      title: create_title, 
      issue_type: "bump", 
      description:,
      ticket_key: nil, 
      jira_link: nil, 
    )
    
    open_browser(pr_url)
  end

  private

  def summary
    log "🚀 Creating Git bump branch and GitHub pull request"
    log "Branch name: #{@branch_name}"
    log "Jira ticket: #{@jira_ticket}"
    log ""
  end

  def create_title
    create_commit_message_from_branch_name
  end

  def get_dependabot_pull_requests(github_repo)
    log "Fetching Dependabot pull requests..."

    response = @github_client.get_all("/repos/#{github_repo[:owner]}/#{github_repo[:repo]}/pulls")
    
    dependabot_prs = response.select do |pr|
      pr['user']['login'] == 'dependabot[bot]'
    end
    
    log "Found #{@dependabot_prs.length} Dependabot pull requests"
    dependabot_prs.each { |pr| log "  - #{pr['title']} (#{pr['head']['ref']})" }

    dependabot_prs
  end

  def cherry_pick_dependabot_commits(dependabot_prs)
    log "Cherry-picking commits from Dependabot PRs..."
    
    dependabot_prs.each do |pr|
      branch_name = pr['head']['ref']
      pr_title = pr['title']
      
      log "\nProcessing PR: #{pr_title}"
      log "Branch: #{branch_name}"
      
      git_fetch_branch(branch_name)
      
      commits = get_pr_commits(pr['number'])
      commit_shas = commits.map { |c| c['sha'] }
      
      puts "Found #{commit_shas.length} commit(s) to cherry-pick"
      
      success = true
      cherry_picked_commits = []
      
      commit_shas.each do |sha|
        puts "  Cherry-picking commit: #{sha[0..7]}"
        
        if system("git cherry-pick #{sha}")
          cherry_picked_commits << sha
          puts "    ✓ Success"
        else
          puts "    ✗ Failed - conflicts detected"
          success = false
          break
        end
      end
      
      unless success
        puts "  Rolling back cherry-picks for this PR due to conflicts..."
        cherry_picked_commits.reverse.each do |sha|
          system("git revert --no-edit #{sha}")
        end
      end
      
      @cherry_pick_results << {
        pr: pr,
        success: success,
        commits: commit_shas,
        branch: branch_name
      }
    end
    
    puts "\nCherry-pick summary:"
    @cherry_pick_results.each do |result|
      status = result[:success] ? "✓" : "✗"
      puts "  #{status} #{result[:pr]['title']}"
    end
  end
  
  def get_pr_commits(github_repo, pr_number)
    @github_client.get_all("/repos/#{github_repo[:owner]}/#{github_repo[:repo]}/pulls/#{pr_number}/commits")
  end

end