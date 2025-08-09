
def open_browser(pr_url)
  log_info "Opening #{pr_url} in browser..."
  
  case RUBY_PLATFORM
  when /darwin/ # macOS
    system("open '#{pr_url}'")
  when /linux/
    system("xdg-open '#{pr_url}'")
  when /mswin|mingw|cygwin/ # Windows
    system("start '#{pr_url}'")
  else
    log "Please open the following URL in your browser: #{pr_url}"
  end
end
