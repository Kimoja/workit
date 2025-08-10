module AttributeInitializer
  def initialize(**kwargs)
    kwargs.each do |key, val|
      instance_variable_set("@#{key}", val)
    end
  end
end
