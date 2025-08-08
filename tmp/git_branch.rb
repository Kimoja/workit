#!/usr/bin/env ruby

require_relative 'deps'

class JiraGitWorkflow
  include GitConcern

  def initialize(issue)
    @issue = issue
    @jira_url = ENV['JIRA_URL'] || raise('JIRA_URL environment variable is required')
    @jira_user = ENV['JIRA_USER'] || raise('JIRA_USER environment variable is required')
    @jira_token = ENV['JIRA_TOKEN'] || raise('JIRA_TOKEN environment variable is required')
    @github_token = ENV['GITHUB_TOKEN'] || raise('GITHUB_TOKEN environment variable is required')
  end

  def run
    git_navigate_to_repo!
    init_github_repo_info
    git_commit_if_changes
    switch_to_master
    ticket_data = fetch_issue
    branch_name = git_create_branch_name(ticket_data)
    create_and_checkout_branch(branch_name)
    commit_message = create_commit_message(ticket_data)
    create_empty_commit(commit_message)
    git_push_branch
    pr_url = create_pull_request(ticket_data, commit_message)
    open_pull_request_in_browser(pr_url)
  end

  private

  def init_github_repo_info
    # Récupère l'URL du repo GitHub depuis la remote origin
    remote_url = `git config --get remote.origin.url`.strip
    
    # Parse l'URL pour extraire owner/repo
    if remote_url.match(/github\.com[\/:](.+)\/(.+)\.git$/)
      owner = $1
      repo = $2
      @github_repo = { owner: owner, repo: repo }
    else
      raise "Unable to parse GitHub repository information from remote URL: #{remote_url}"
    end
  end

  def fetch_issue
    puts "Fetching Jira ticket: #{@issue}"
    
    uri = URI("#{@jira_url}/rest/api/2/issue/#{@issue}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Basic #{Base64.strict_encode64("#{@jira_user}:#{@jira_token}")}"
    request['Content-Type'] = 'application/json'
    
    response = http.request(request)
    
    unless response.code == '200'
      puts "Error fetching Jira ticket: #{response.code} - #{response.body}"
      exit 1
    end
    
    JSON.parse(response.body)
  end

  def git_create_branch_name(ticket_data)
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

  def create_commit_message(ticket_data)
    issue_type = ticket_data.dig('fields', 'issuetype', 'name')&.downcase
    title = (ticket_data.dig('fields', 'summary') || '').gsub(/^\[.*?\]\s*/, '')
    ticket_key = @issue.upcase
    
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
    <<~TEMPLATE
      ## 📔 Ticket(s):

      -

      ## 📝 Types de changements:

      - [ ] Bug fix (changements non-cassants qui resout un problème)
      - [ ] Nouvelle fonctionnalité (changement non-cassant qui ajoute des fonctionnalités)
      - [ ] Breaking change (correction ou fonctionnalité qui pourrait causer des problèmes dans les applications existantes)
      - [ ] Mise à jour de la documentation
      - [ ] Refactoring
      - [ ] Mise à jour de gems

      ## 📓 Description:

      -

      ## 📸 Images (optionnel):

      -

      ## 📋 Checklist:

      - [ ] J'ai fait une review de mon propre code
      - [ ] J'ai commenté mon code, en particulier dans les parties difficiles à comprendre
      - [ ] J'ai mis à jour la documentation si nécessaire
      - [ ] J'ai ajouté des tests associés aux changements que j'ai réalisés
      - [ ] J'ai deployé en staging et la QA a testé la branche

      ## Resources utiles

      -
    TEMPLATE
  end

  def prepare_pr_description(ticket_data)
    template = fetch_pr_template
    issue_type = ticket_data.dig('fields', 'issuetype', 'name')&.downcase
    ticket_key = @issue.upcase
    jira_link = "#{@jira_url}/browse/#{ticket_key}"
    
    # Cocher la bonne case selon le type de ticket
    if issue_type == 'bug'
      template = template.gsub('- [ ] Bug fix', '- [x] Bug fix')
    else
      template = template.gsub('- [ ] Nouvelle(s) fonctionnalité(s)', '- [x] Nouvelle fonctionnalité')
    end
    
    # Ajouter le lien Jira
    template = template.gsub('## 📔 Ticket(s):', "## 📔 Ticket(s):\n\n- [#{ticket_key}](#{jira_link})")
    
    # Ajouter la description du ticket
    description = ticket_data.dig('fields', 'description')
    if description && !description.strip.empty?
      # Nettoyer la description Jira (enlever le markup Jira)
      clean_description = description.gsub(/\{[^}]+\}/, '').strip
      template = template.gsub('## 📓 Description:', "## 📓 Description:\n\n#{clean_description}")
    else
      # Utiliser le titre si pas de description
      title = ticket_data.dig('fields', 'summary') || ''
      template = template.gsub('## 📓 Description:', "## 📓 Description:\n\n#{title}")
    end
    
    template
  end

  def create_pull_request(ticket_data, commit_message)
    puts "Creating pull request..."
    
    # Récupérer la branche courante
    current_branch = `git branch --show-current`.strip
    base_branch = 'master' # ou 'main' selon votre repo
    
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

def main
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    
    opts.on('-t', '--jira-ticket TICKET', 'Jira ticket (e.g., KRAFT-3735)') do |ticket|
      options[:issue] = ticket
    end
    
    opts.on('-h', '--help', 'Show this help') do
      puts opts
      exit
    end
  end.parse!

  unless options[:issue]
    puts "Error: --jira-ticket is required"
    puts "Usage: #{$0} --jira-ticket KRAFT-3735"
    exit 1
  end

  begin
    workflow = JiraGitWorkflow.new(options[:issue])
    workflow.run
    puts "Workflow completed successfully!"
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end
end

# Point d'entrée du script
main if __FILE__ == $0