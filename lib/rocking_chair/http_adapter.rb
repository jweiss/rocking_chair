# encoding: utf-8

module RockingChair
  module HttpAdapter
    
    def http_adapter
      unless @_restclient
        @_restclient = Object.new
        @_restclient.extend(RestAPI)
      end
      
      if RockingChair.enabled?
        RockingChair::CouchRestHttpAdapter
      else
        @_restclient
      end
    end
  
    def get(uri, headers=nil)
      result = http_adapter.get(uri)
      if result.is_a?(String)
        JSON.parse(result)
      else
        result
      end
    end
  
    def post(uri, payload, headers=nil)
      result = http_adapter.post(uri, payload)
      if result.is_a?(String)
        JSON.parse(result)
      else
        result
      end
    end
  
    def put(uri, payload=nil, headers=nil)
      result = http_adapter.put(uri, payload)
      if result.is_a?(String)
        JSON.parse(result)
      else
        result
      end
    end
  
    def delete(uri, headers=nil)
      result = http_adapter.delete(uri)
      if result.is_a?(String)
        JSON.parse(result)
      else
        result
      end
    end
  
    def copy(uri, destination)
      result = http_adapter.copy(uri, default_headers.merge('Destination' => destination))
      if result.is_a?(String)
        JSON.parse(result)
      else
        result
      end
    end    
 
  end
end

CouchRest.extend(RockingChair::HttpAdapter)