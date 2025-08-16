module Commands
  module Open
    class BrowserAliasesCommand
      include Command

      self.function = "open-browser-aliases"
      self.aliases = ["b"]
      self.summary = "Open browser URLs from configured aliases"

      def call
        parse_options

        Domain::Open.browser_aliases(ARGV)
      end

      private

      def parse_options
        OptionParser.new do |opts|
          opts.banner = "Usage: #{self.class.function} ALIAS_NAME [ALIAS_NAME...]\n\n#{self.class.summary}"
          opts.separator ''
          opts.separator 'Arguments:'
          opts.separator '  ALIAS_NAME  Name(s) of browser aliases to open (from config)'
          opts.separator ''

          opts.on('-h', '--help', 'Show this help') do
            show_help(opts)
            exit
          end
        end.parse!

        {}
      end

      def show_help(opts)
        Log.log opts
        Log.log ''
        Log.log 'Examples:'
        Log.log "  #{self.class.function} github"
        Log.log "  #{self.class.function} dev prod"
        Log.log "  bro work personal  # Using alias"
        Log.log ''
        Log.log 'Configuration:'
        Log.log '  Define aliases in config under "browser_aliases":'
        Log.log ''
        Log.log '  "browser_aliases": {'
        Log.log '    "github": "https://github.com",'
        Log.log '    "work": ["https://jira.company.com", "https://confluence.company.com"],'
        Log.log '    "dev": "@work"  // Reference to another alias'
        Log.log '  }'
        Log.log ''
        Log.log 'Behavior:'
        Log.log '  • Single URL: Opens one browser tab'
        Log.log '  • Array of URLs: Opens multiple browser tabs'
        Log.log '  • Reference (@alias): Resolves and opens the referenced alias'
        Log.log '  • Multiple aliases: Processes each one in sequence'
        Log.log ''
        Log.log 'Alias Types:'
        Log.log '  • Direct URL: "github": "https://github.com"'
        Log.log '  • URL Array: "work": ["url1", "url2"]'
        Log.log '  • Reference: "dev": "@work" (points to work alias)'
      end
    end
  end
end
