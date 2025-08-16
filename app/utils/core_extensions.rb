# app/core_extensions.rb
module CoreExtensions
  module Object
    # Returns true if the object is present (not blank)
    def present?
      !blank?
    end

    # Returns true if the object is blank
    def blank?
      respond_to?(:empty?) ? !!empty? : !self
    end
  end

  module String
    def blank?
      # A string is blank if it's empty or contains only whitespace
      empty? || match?(/\A[[:space:]]*\z/)
    end
  end

  module NilClass
    def blank?
      true
    end
  end

  module FalseClass
    def blank?
      true
    end
  end

  module TrueClass
    def blank?
      false
    end
  end

  module Array
    def blank?
      empty?
    end
  end

  module Hash
    def blank?
      empty?
    end
  end

  module Numeric
    def blank?
      false
    end
  end
end

# Étendre les classes Ruby avec nos extensions
Object.include(CoreExtensions::Object)
String.include(CoreExtensions::String)
NilClass.include(CoreExtensions::NilClass)
FalseClass.include(CoreExtensions::FalseClass)
TrueClass.include(CoreExtensions::TrueClass)
Array.include(CoreExtensions::Array)
Hash.include(CoreExtensions::Hash)
Numeric.include(CoreExtensions::Numeric)
