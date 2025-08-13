class Service < Callable
  include AttributeInitializer
  include Utils
  include Uinit::Memoizable

  def valid_attribute_or_ask(attribute:, text:, &validator)
    return if validator.call

    Prompt.ask(text:) do |response|
      instance_variable_set("@#{attribute}", response)

      return if validator.call

      raise text
    end
  end

  def valid_attribute_or_select(attribute:, text:, options:, default: nil, &validator)
    return if validator.call

    Prompt.select(text:, options:, default:) do |response|
      instance_variable_set("@#{attribute}", response)

      return if validator.call

      raise text
    end
  end
end
