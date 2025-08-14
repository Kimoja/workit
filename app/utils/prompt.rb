module Utils
  module Prompt
    extend self

    def prompt
      @prompt ||= TTY::Prompt.new
    end

    def yes_no(text:, yes: nil, no: nil)
      Play.promt

      if prompt.yes?("❓ #{text}")
        yes ? yes.call : true
      else
        no ? no.call : false
      end
    end

    def ask(text:, default: nil)
      Play.promt

      prompt_text = "❓ #{text}"
      prompt_text += " [#{default}]" if default

      response = prompt.ask(prompt_text, default:)

      return yield(response) if block_given?

      response
    end

    def select(text:, options:, default: nil)
      Play.promt

      prompt_text = "❓ #{text}"
      prompt_text += " (default: '#{default}')" if default

      response = prompt.select(prompt_text, options)

      return yield(response) if block_given?

      response
    end
  end
end
