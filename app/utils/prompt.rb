module Utils
  module Prompt
    extend self

    def prompt
      @prompt ||= TTY::Prompt.new
    end

    # rubocop:disable Naming/MethodParameterName
    def yes_no(text:, yes: nil, no: nil)
      Play.promt

      if prompt.yes?("\e[31m?\e[0m #{text}")
        yes ? yes.call : true
      else
        no ? no.call : false
      end
    end
    # rubocop:enable Naming/MethodParameterName

    def ask(text:, default: nil)
      Play.promt

      prompt_text = "\e[31m?\e[0m #{text}"
      prompt_text += " [#{default}]" if default

      response = prompt.ask(prompt_text, default:)

      return yield(response) if block_given?

      response
    end

    def select(text:, options:, default: nil)
      Play.promt

      prompt_text = "\e[31m?\e[0m #{text}"
      prompt_text += " (default: '#{default}')" if default

      response = prompt.select(prompt_text, options)

      return yield(response) if block_given?

      response
    end
  end
end
