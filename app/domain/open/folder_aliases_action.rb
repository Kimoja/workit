module Domain
  module Open
    class FolderAliasesAction
      include Action

      attr_reader :alias_names

      def call
        summary
        resolve_and_open_aliases
        report
      end

      private

      def summary
        Log.start "Opening folder aliases: #{alias_names.join(', ')}"
      end

      def resolve_and_open_aliases
        alias_names.each do |alias_name|
          Log.info "Processing alias: #{alias_name}"
          paths = resolve_alias(alias_name)
          open_folders(paths)
        end
      end

      def resolve_alias(alias_name, visited = Set.new)
        if visited.include?(alias_name)
          Log.error "Circular reference detected for alias: #{alias_name}"
          return []
        end
        visited.add(alias_name)

        alias_value = Config.get('folder_aliases', alias_name)

        unless alias_value
          Log.error "Folder alias '#{alias_name}' not found in config"
          return []
        end

        case alias_value
        when String
          if alias_value.start_with?('@')
            referenced_alias = alias_value[1..-1]
            Log.info "Resolving reference: #{alias_name} -> #{referenced_alias}"
            resolve_alias(referenced_alias, visited)
          else
            [expand_path(alias_value)]
          end
        when Array
          alias_value.flat_map do |item|
            if item.start_with?('@')
              referenced_alias = item[1..-1]
              resolve_alias(referenced_alias, visited)
            else
              [expand_path(item)]
            end
          end
        else
          Log.error "Invalid alias format for '#{alias_name}': #{alias_value.class}"
          []
        end
      end

      def expand_path(path)
        File.expand_path(path)
      end

      def open_folders(paths)
        return if paths.empty?

        paths.each do |path|
          if File.directory?(path)
            Log.info "Opening folder: #{path}"
            Utils::System.open_folder(path)
          else
            Log.warn "Path does not exist or is not a directory: #{path}"
          end
        end
      end

      def report
        Log.success "Folder aliases opened successfully"
      end
    end
  end
end
