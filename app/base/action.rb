module Action
  include AttributeInitializer
  include Utils

  def self.included(base)
    base.include Callable
    base.include Uinit::Memoizable
  end

  def ask_for_attribute(attribute:, text:, default: nil)
    default = default.is_a?(Proc) ? default.call : default

    Prompt.ask(text:) do |response|
      instance_variable_set("@#{attribute}", response || default)

      yield if block_given?
    end
  end

  def valid_attribute_or_ask(attribute:, text:, default: nil, &validator)
    return if validator.call

    ask_for_attribute(attribute:, text:, default:) do
      raise text unless validator.call
    end
  end

  def select_for_attribute(attribute:, text:, options:, default: nil)
    options = options.is_a?(Proc) ? options.call : options
    default = default.is_a?(Proc) ? default.call : default

    options.delete(default)
    options.unshift(default)

    Prompt.select(text:, options:, default:) do |response|
      instance_variable_set("@#{attribute}", response)

      yield if block_given?
    end
  end

  def valid_attribute_or_select(attribute:, text:, options:, default: nil, &validator)
    return if validator.call

    select_for_attribute(attribute:, text:, options:, default:) do
      raise text unless validator.call
    end
  end
end
