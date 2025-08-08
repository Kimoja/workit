module Domain
  module Open
    class BrowserAliasesAction
      include Action

      attr_reader :alias_names

      def call
        summary
        resolve_and_open_aliases
        report
      end

      private

      def summary
        Log.start "Opening browser aliases: #{alias_names.join(', ')}"
      end

      def resolve_and_open_aliases
        alias_names.each do |alias_name|
          Log.info "Processing alias: #{alias_name}"
          urls = resolve_alias(alias_name)
          open_urls(urls)
        end
      end

      def resolve_alias(alias_name, visited = Set.new)
        # Éviter les références circulaires
        if visited.include?(alias_name)
          Log.error "Circular reference detected for alias: #{alias_name}"
          return []
        end
        visited.add(alias_name)

        alias_value = Config.get('browser_aliases', alias_name)

        unless alias_value
          Log.error "Browser alias '#{alias_name}' not found in config"
          return []
        end

        case alias_value
        when String
          if alias_value.start_with?('@')
            # C'est une référence vers un autre alias
            referenced_alias = alias_value[1..]
            Log.info "Resolving reference: #{alias_name} -> #{referenced_alias}"
            resolve_alias(referenced_alias, visited)
          else
            # C'est une URL directe
            [alias_value]
          end
        when Array
          # C'est un tableau d'URLs
          alias_value.flat_map do |item|
            if item.start_with?('@')
              referenced_alias = item[1..]
              resolve_alias(referenced_alias, visited)
            else
              [item]
            end
          end
        else
          Log.error "Invalid alias format for '#{alias_name}': #{alias_value.class}"
          []
        end
      end

      def open_urls(urls)
        return if urls.empty?

        urls.each do |url|
          Log.info "Opening: #{url}"
          Utils::Open.browser(url)
        end
      end

      def report
        Log.success "Browser aliases opened successfully"
      end
    end
  end
end
