class BaseService
  def self.call(**, &)
    new(**, &).call
  end

  def initialize(**kwargs)
    kwargs.each do |key, val|
      instance_variable_set("@#{key}", val)
    end
  end
end
