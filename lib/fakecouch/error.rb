module Fakecouch
  class Error < StandardError
    
    attr_reader :code, :error, :reason
    
    def initialize(code, error, reason)
      @code = code
      @error = error
      @reason = reason
    end
    
    def message
      "#{@code} - #{@error} - #{@reason}"
    end
    
    def to_json
      {"error" => @error, "reason" => @reason }.to_json
    end
    
    def raise_rest_client_error
      case code
      when 404
        raise RestClient::ResourceNotFound
      when 409
        raise HttpAbstraction::Conflict
      else
        raise "Unknown error code: #{code.inspect}"
      end
    end
    
    def self.raise_404
      raise Fakecouch::Error.new(404, 'not_found', "missing")
    end
    
    def self.raise_409
      raise Fakecouch::Error.new(409, 'conflict', "Document update conflict.")
    end
    
    def self.raise_500
      raise Fakecouch::Error.new(500, 'invalid', "the document is invalid.")
    end
    
  end
end