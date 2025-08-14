module Action
  include AttributeInitializer
  include Utils

  def self.included(base)
    base.include Callable
    base.include Uinit::Memoizable
  end

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
