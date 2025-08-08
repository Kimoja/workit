module Commands
  class OpenBrowserAliasesCommand
    def call
      Log.log '🚀 Open Browser Aliases'

      raise 'Missing aliases arguments' if ARGV.empty?

      ARGV.each do |alia|
        resolve_urls(alia).flatten.each { |url| Open.browser(url) if url }
      end
    end

    def resolve_urls(alia)
      url = config.browser_aliases[alia]

      if url.nil?
        Log.error "No URL found for alias '#{alia}'"
        return nil
      end

      if url.is_a?(Array)
        url.map do |ur|
          if ur.start_with?('@')
            resolve_urls(ur.sub('@', ''))
          else
            [ur]
          end
        end
      else
        return resolve_urls(url.sub('@', '')) if url.start_with?('@')

        [url]
      end
    end
  end
end
