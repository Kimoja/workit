module Command
  include Utils

  def self.included(base)
    base.include Callable
    base.attr_reader :options
  end

  def initialize(*)
    super
    @options = {}
  end
end
