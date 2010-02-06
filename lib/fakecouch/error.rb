module Fakecouch
  class Error < StandardError
    
    attr_reader :code
    
    def initialize(code, error, reason)
      @code = code
      @error = error
      @reason = reason
    end
    
    def message
      "#{@code} - #{@error} - #{@reason}"
    end
    
  end
end