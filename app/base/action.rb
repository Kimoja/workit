module Action
  include AttributeInitializer
  include Utils

  def self.included(base)
    base.include Callable
    base.include Uinit::Memoizable
  end

  def ask_for_attribute(attribute:, text:, default: nil, formatter: nil)
    default = default.call if default.is_a?(Proc)

    Prompt.ask(text:) do |response|
      formatted_value = formatter ? formatter.call(response) : response
      instance_variable_set("@#{attribute}", formatted_value || default)

      yield if block_given?
    end
  end

  def valid_attribute_or_ask(attribute:, text:, default: nil, formatter: nil, &validator)
    return if validator.call

    ask_for_attribute(attribute:, text:, default:, formatter:) do
      raise text unless validator.call
    end
  end

  def select_for_attribute(attribute:, text:, options:, default: nil, formatter: nil)
    options = options.call if options.is_a?(Proc)
    default = default.call if default.is_a?(Proc)

    options.delete(default)
    options.unshift(default)

    Prompt.select(text:, options:, default:) do |response|
      formatted_value = formatter ? formatter.call(response) : response

      instance_variable_set("@#{attribute}", formatted_value)

      yield if block_given?
    end
  end

  def valid_attribute_or_select(attribute:, text:, options:, default: nil, formatter: nil, &validator)
    return if validator.call

    select_for_attribute(attribute:, text:, options:, default:, formatter:) do
      raise text unless validator.call
    end
  end
end
