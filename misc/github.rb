
def github_repo_info
  remote_url = `git config --get remote.origin.url`.strip
  
  if remote_url.match(/github\.com[\/:](.+)\/(.+)\.git$/)
    owner = $1
    repo = $2
    { owner: owner, repo: repo }
  else
    raise "Unable to parse GitHub repository information from remote URL: #{remote_url}"
  end
end