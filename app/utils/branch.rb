module Utils
  module Branch
    extend self

    def commit_message_from_branch(branch)
      result = branch

      if result =~ %r{^([^/]+)/}
        prefix = ::Regexp.last_match(1).upcase
        result = "[#{prefix}] #{result.sub(%r{^[^/]+/}, '')}"
      end

      if result =~ /^(\[.+?\]\s+)?([A-Z]+-\d+)-(.+)/
        prefix_part = ::Regexp.last_match(1) || ''
        pattern = ::Regexp.last_match(2)
        remaining = ::Regexp.last_match(3)
        result = "#{prefix_part}#{pattern} - #{remaining}"
      end

      if result =~ /^(\[.+?\]\s+)?(.*?\s-\s)?(.*)/
        prefix_part = ::Regexp.last_match(1) || ''
        pattern_part = ::Regexp.last_match(2) || ''
        remaining = ::Regexp.last_match(3) || result

        # Si on a déjà traité des parties, ne traiter que le remaining
        text_to_transform = if !prefix_part.empty? || !pattern_part.empty?
                              remaining
                            else
                              result
                            end

        # Transformer la partie restante
        unless text_to_transform.empty?
          # Remplacer tous les tirets par des espaces
          transformed = text_to_transform.gsub('-', ' ')
          # Capitaliser le premier mot
          words = transformed.split
          words[0] = words[0].capitalize if words[0] && !words[0].empty?
          transformed = words.join(' ')

          result = "#{prefix_part}#{pattern_part}#{transformed}"
        end
      end

      result
    end
  end
end
