module Utils
  module Prompt
    extend self

    def yes_no(text:, yes: nil, no: nil)
      Play.promt

      Log.log "❓ #{text} (y/N): "

      response = STDIN.gets.chomp.downcase

      if %w[y yes].include?(response)
        yes ? yes.call : true
      else
        no ? no.call : false
      end
    end

    def ask(text:, default: nil)
      Play.promt

      prompt_text = "❓ #{text}"
      prompt_text += " [#{default}]" if default
      prompt_text += ": "

      Log.log prompt_text

      response = STDIN.gets.chomp.strip
      response = default if response.empty? && default

      return yield(response) if block_given?

      response
    end
  end
end
