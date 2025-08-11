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
  end
end
