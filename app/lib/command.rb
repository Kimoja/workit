class Command < Callable
  include Utils

  attr_reader :options

  def initialize
    super
    @options = {}
  end
end
