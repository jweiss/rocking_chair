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
    
    def to_json
      {"error" => @error, "reason" => @reason }.to_json
    end
    
    def raise_rest_client_error
      case code
      when 404
        raise RestClient::ResourceNotFound
      when 409
        raise RestClient::ResourceNotFound
      else
        raise "Unknown error code: #{code.inspect}"
      end
    end
    
  end
end