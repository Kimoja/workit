
def open_browser_aliases_command
  log "🚀 Open Browser Aliases"

  raise "Missing aliases arguments" if ARGV.empty?

  ARGV.each do |alia|
    resolve_urls(alia).flatten.each { |url| open_browser(url) if url }
  end
end

def resolve_urls(alia)
  url = config.browser_aliases[alia]
  
  if url.nil?
    log_error "No URL found for alias '#{alia}'"
    return nil
  end
  
  if url.is_a?(Array)
    url.map do |ur|
      if ur.start_with?("@")
        resolve_urls(ur.sub("@", ""))
      else
        [ur]
      end
    end
  else
    if url.start_with?("@")
      return resolve_urls(url.sub("@", ""))
    end

    [url]
  end
end