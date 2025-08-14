class Service < Callable
  include AttributeInitializer
  include Utils
  include Uinit::Memoizable

  def valid_attribute_or_ask(attribute:, text:, default: nil, &validator)
    return if validator.call

    Prompt.ask(text:) do |response|
      instance_variable_set("@#{attribute}", response || default)

      return if validator.call

      raise text
    end
  end

  def valid_attribute_or_select(attribute:, text:, options:, default: nil, &validator)
    return if validator.call

    options.delete(default)
    options.unshift(default)

    # rubocop:disable Lint/UnreachableLoop
    Prompt.select(text:, options:, default:) do |response|
      instance_variable_set("@#{attribute}", response)

      return if validator.call

      raise text
    end
    # rubocop:enable Lint/UnreachableLoop
  end
end
