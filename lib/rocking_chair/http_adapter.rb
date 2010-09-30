module RockingChair
  module HttpAdapter
    
    def http_adapter
      unless @_restclient
        @_restclient = Object.new
        @_restclient.extend(RestClientAdapter::API)
      end
      
      if RockingChair.enabled?
        RockingChair::CouchRestHttpAdapter
      else
        @_restclient
      end
    end
  
    def get(uri, headers=nil)
      JSON.parse(http_adapter.get(uri, headers))
    end
  
    def post(uri, payload, headers=nil)
      JSON.parse(http_adapter.post(uri, payload, headers))
    end
  
    def put(uri, payload=nil, headers=nil)
      JSON.parse(http_adapter.put(uri, payload, headers))
    end
  
    def delete(uri, headers=nil)
      JSON.parse(http_adapter.delete(uri, headers))
    end
  
    def copy(uri, destination)
      JSON.parse(http_adapter.copy(uri, default_headers.merge('Destination' => destination)))
    end    
 
  end
end

#::RestAPI.extend(RockingChair::HttpAdapter)
CouchRest.extend(RockingChair::HttpAdapter)