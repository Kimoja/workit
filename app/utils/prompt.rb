module Utils
  module Prompt
    extend self

    def prompt
      @prompt ||= TTY::Prompt.new
    end

    # rubocop:disable Naming/MethodParameterName
    def confirm(text, yes: nil, no: nil)
      System.play_promt

      if prompt.yes?("\e[31m?\e[0m #{text}")
        yes ? yes.call : true
      else
        no ? no.call : false
      end
    end
    # rubocop:enable Naming/MethodParameterName

    def ask(text, default: nil, formatter: nil)
      System.play_promt

      default = default.call if default.is_a?(Proc)

      prompt_text = "\e[31m?\e[0m #{text}"
      prompt_text += " [#{default}]" if default

      response = prompt.ask(prompt_text, default:)
      formatted_response = formatter ? formatter.call(response) : response

      return yield(formatted_response) if block_given?

      response
    end

    def select(text, options, default: nil, formatter: nil)
      System.play_promt

      options = options.call if options.is_a?(Proc)
      default = default.call if default.is_a?(Proc)

      options.delete(default)
      options.unshift(default)

      prompt_text = "\e[31m?\e[0m #{text}"
      prompt_text += " (default: '#{default}')" if default

      response = prompt.select(prompt_text, options)
      formatted_response = formatter ? formatter.call(response) : response

      return yield(formatted_response) if block_given?

      response
    end
  end
end
