module Commands
  class OpenFileExplorerAliasesCommand
    def call
      Log.log '🚀 Open Explorer Aliases'

      raise 'Missing aliases arguments' if ARGV.empty?

      ARGV.each do |alia|
        resolve_paths(alia).flatten.each { |path| Open.file_explorer(path) if path }
      end
    end

    def resolve_paths(alia)
      path = config.file_explorer_aliases[alia]

      if path.nil?
        Log.error "No Path found for alias '#{alia}'"
        return nil
      end

      if path.is_a?(Array)
        path.map do |ur|
          if ur.start_with?('@')
            resolve_paths(ur.sub('@', ''))
          else
            [ur]
          end
        end
      else
        return resolve_paths(path.sub('@', '')) if path.start_with?('@')

        [path]
      end
    end
  end
end
