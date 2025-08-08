module Command
  include Utils

  def self.included(base)
    base.extend(ClassMethods)
    base.include Callable
    base.attr_reader :options
  end

  module ClassMethods
    def function=(function)
      @function = function
    end

    def function
      @function || raise("Function name not set for #{self}")
    end

    def aliases=(aliases)
      @aliases = aliases
    end

    def aliases
      @aliases || []
    end

    def summary=(summary)
      @summary = summary
    end

    def summary
      @summary || ""
    end
  end

  def initialize(*)
    super
    @options = {}
  end
end
