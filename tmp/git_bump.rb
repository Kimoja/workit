#!/usr/bin/env ruby

require_relative 'deps'

class GitBumpWorkflow
  include GitConcern

  def initialize
    @github_token = ENV['GITHUB_TOKEN'] || raise('GITHUB_TOKEN environment variable is required')
    @branch_name = nil
    @dependabot_prs = []
    @cherry_pick_results = []
  end

  def run
    git_navigate_to_repo!
    initialize_repo_info
    git_commit_if_changes
    switch_to_master

    git_create_branch
    get_dependabot_pull_requests
    cherry_pick_commits_from_pull_requests
    bundle_update
    # git_push_branch
    pr_description = create_pull_request_description
    binding.pry 

    raise 


    create_pull_request(pr_description)
    open_pull_request_in_browser
  end

  private

  def initialize_repo_info
    remote_url = `git remote get-url origin`.strip
    if remote_url.match(/github\.com[\/:](.+?)\/(.+?)(?:\.git)?$/)
      @repo_info = { owner: $1, repo: $2.gsub('.git', '') }
    else
      raise "Could not parse GitHub repository information from: #{remote_url}"
    end
  end

  def git_create_branch
    today = Date.today.strftime('%Y-%m-%d')
    @branch_name = "dump/#{today}"
    
    puts "Creating branch: #{@branch_name}"
    system("git checkout -b #{@branch_name}") || raise("Failed to create branch: #{@branch_name}")
  end

  def get_dependabot_pull_requests
    puts "Fetching Dependabot pull requests..."
    
    uri = URI("https://api.github.com/repos/#{@repo_info[:owner]}/#{@repo_info[:repo]}/pulls")
    uri.query = URI.encode_www_form({
      state: 'open',
      per_page: 100
    })
    
    response = github_api_request(uri)
    
    @dependabot_prs = response.select do |pr|
      pr['user']['login'] == 'dependabot[bot]'
    end
    
    puts "Found #{@dependabot_prs.length} Dependabot pull requests"
    @dependabot_prs.each { |pr| puts "  - #{pr['title']} (#{pr['head']['ref']})" }
  end

  def cherry_pick_commits_from_pull_requests
    puts "Cherry-picking commits from Dependabot PRs..."
    
    @dependabot_prs.each do |pr|
      branch_name = pr['head']['ref']
      pr_title = pr['title']
      
      puts "\nProcessing PR: #{pr_title}"
      puts "Branch: #{branch_name}"
      
      # Fetch the branch
      system("git fetch origin #{branch_name}:#{branch_name}")
      
      # Get commits in the PR
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

  def get_pr_commits(pr_number)
    uri = URI("https://api.github.com/repos/#{@repo_info[:owner]}/#{@repo_info[:repo]}/pulls/#{pr_number}/commits")
    github_api_request(uri)
  end

  def bundle_update
    puts "Running bundle update..."
    system("bundle update") || raise("Failed to run bundle update")
  end

  def create_pull_request_description
    puts "Creating pull request description..."
    
    # Read template file
    template_path = 'pull_request_template.md'
    unless File.exist?(template_path)
      puts "Warning: pull_request_template.md not found, using default template"
      return create_default_pr_description
    end
    
    template_content = File.read(template_path)
    
    # Check "Mise à jour de gems" checkbox
    template_content.gsub!(/- \[ \] Mise à jour de gems/, '- [x] Mise à jour de gems')
    
    # Remove "Ticket(s):" section
    template_content.gsub!(/## 📔 Ticket\(s\):.*?(?=##)/m, '')
    
    # Add dependabot branches information in description
    dependabot_info = create_dependabot_summary
    template_content.gsub!(/## 📓 Description:\s*-/, "## 📓 Description:\n\n#{dependabot_info}")
    
    template_content
  end

  def create_default_pr_description
    dependabot_info = create_dependabot_summary
    
    <<~DESC
      ## 📝 Types de changements:

      - [x] Mise à jour de gems

      ## 📓 Description:

      #{dependabot_info}

      ## 📋 Checklist:

      - [ ] J'ai fait une review de mon propre code
      - [ ] J'ai commenté mon code, en particulier dans les parties difficiles à comprendre
      - [ ] J'ai mis à jour la documentation si nécessaire
      - [ ] J'ai ajouté des tests associés aux changements que j'ai réalisés
      - [ ] J'ai deployé en staging et la QA a testé la branche
    DESC
  end

  def create_dependabot_summary
    summary = "Mise à jour automatique des gems via Dependabot.\n\n"
    summary += "**Branches Dependabot traitées:**\n\n"
    
    @cherry_pick_results.each do |result|
      status_icon = result[:success] ? "✅" : "❌"
      status_text = result[:success] ? "Cherry-pick réussi" : "Cherry-pick échoué (conflits)"
      
      # Ajouter le lien vers la PR
      pr_link = "[##{result[:pr]['number']}](#{result[:pr]['html_url']})"
      
      summary += "- #{status_icon} `#{result[:branch]}` - #{result[:pr]['title']} #{pr_link} (#{status_text})\n"
      
      # Si échec, ajouter les SHA1 des commits à appliquer manuellement
      unless result[:success]
        summary += "  - **Commits à appliquer manuellement:**\n"
        result[:commits].each do |sha|
          commit_short = sha[0..7]
          commit_link = "https://github.com/#{@repo_info[:owner]}/#{@repo_info[:repo]}/commit/#{sha}"
          summary += "    - [`#{commit_short}`](#{commit_link})\n"
        end
      end
    end
    
    if @cherry_pick_results.any? { |r| !r[:success] }
      summary += "\n⚠️ **Note:** Certains cherry-picks ont échoué à cause de conflits. "
      summary += "Ces changements devront être appliqués manuellement en utilisant les liens des commits ci-dessus.\n"
    end
    
    summary
  end

  def create_pull_request(description)
    puts "Creating pull request..."
    
    today = Date.today.strftime('%Y-%m-%d')
    title = "[BUMP] #{today}"
    
    uri = URI("https://api.github.com/repos/#{@repo_info[:owner]}/#{@repo_info[:repo]}/pulls")
    
    payload = {
      title: title,
      body: description,
      head: @branch_name,
      base: 'master'
    }
    
    response = github_api_request(uri, :post, payload)
    
    @pr_url = response['html_url']
    puts "Pull request created: #{@pr_url}"
    
    response
  end

  def open_pull_request_in_browser
    return unless @pr_url
    
    puts "Opening pull request in browser..."
    
    case RbConfig::CONFIG['host_os']
    when /darwin/
      system("open '#{@pr_url}'")
    when /linux/
      system("xdg-open '#{@pr_url}'")
    when /mswin|mingw|cygwin/
      system("start '#{@pr_url}'")
    else
      puts "Please open the following URL in your browser:"
      puts @pr_url
    end
  end

  def github_api_request(uri, method = :get, payload = nil)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = case method
              when :get
                Net::HTTP::Get.new(uri)
              when :post
                req = Net::HTTP::Post.new(uri)
                req.body = payload.to_json if payload
                req
              end
    
    request['Authorization'] = "Bearer #{@github_token}"
    request['Accept'] = 'application/vnd.github.v3+json'
    request['Content-Type'] = 'application/json' if payload
    
    response = http.request(request)
    
    unless response.code.start_with?('2')
      raise "GitHub API request failed: #{response.code} - #{response.body}"
    end
    
    JSON.parse(response.body)
  end
end

def main
  begin
    workflow = GitBumpWorkflow.new
    workflow.run
    puts "Workflow completed successfully!"
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end
end

# Point d'entrée du script
main if __FILE__ == $0