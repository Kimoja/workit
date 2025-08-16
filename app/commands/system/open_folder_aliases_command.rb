module Commands
  module System
    class OpenFolderAliasesCommand
      include Command

      self.function = "open-folder-aliases"
      self.aliases = ["f"]
      self.summary = "Open folders from configured aliases"

      def call
        parse_options

        Operations::System.open_folder_aliases(ARGV)
      end

      private

      def parse_options
        OptionParser.new do |opts|
          opts.banner = "Usage: #{self.class.function} ALIAS_NAME [ALIAS_NAME...]\n\n#{self.class.summary}"
          opts.separator ''
          opts.separator 'Arguments:'
          opts.separator '  ALIAS_NAME  Name(s) of folder aliases to open (from config)'
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
        Log.log "  #{self.class.function} workspace"
        Log.log "  #{self.class.function} projects docs"
        Log.log "  folders work personal  # Using alias"
        Log.log ''
        Log.log 'Configuration:'
        Log.log '  Define aliases in config under "folder_aliases":'
        Log.log ''
        Log.log '  "folder_aliases": {'
        Log.log '    "workspace": ".workspace",'
        Log.log '    "projects": ["/Users/me/dev", "/Users/me/projects"],'
        Log.log '    "work": "@projects"  // Reference to another alias'
        Log.log '  }'
        Log.log ''
        Log.log 'Behavior:'
        Log.log '  • Single path: Opens one folder'
        Log.log '  • Array of paths: Opens multiple folders'
        Log.log '  • Reference (@alias): Resolves and opens the referenced alias'
        Log.log '  • Multiple aliases: Processes each one in sequence'
        Log.log ''
        Log.log 'Alias Types:'
        Log.log '  • Direct path: "workspace": ".workspace"'
        Log.log '  • Path Array: "projects": ["~/dev", "~/work"]'
        Log.log '  • Reference: "all": "@projects" (points to projects alias)'
      end
    end
  end
end
