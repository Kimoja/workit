module Action
  include AttributeInitializer
  include Utils

  def self.included(base)
    base.include Callable
    base.include Uinit::Memoizable
  end

  def ask_for_attribute(attribute, text, default: nil, formatter: nil)
    Prompt.ask(text, default:, formatter:) do |response|
      instance_variable_set("@#{attribute}", response || default)

      yield if block_given?
    end
  end

  def valid_attribute_or_ask(attribute, text, default: nil, formatter: nil, &validator)
    return if validator.call

    ask_for_attribute(attribute:, text:, default:, formatter:) do
      raise text unless validator.call
    end
  end

  def select_for_attribute(attribute, text, options, default: nil, formatter: nil)
    Prompt.select(text, options, default:, formatter:) do |response|
      instance_variable_set("@#{attribute}", response)

      yield if block_given?
    end
  end

  def valid_attribute_or_select(attribute, text, options, default: nil, formatter: nil, &validator)
    return if validator.call

    select_for_attribute(attribute, text, options, default:, formatter:) do
      raise text unless validator.call
    end
  end
end
