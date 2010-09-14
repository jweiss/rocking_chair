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
      http_adapter.get(uri, headers)
    end
  
    def post(uri, payload, headers=nil)
      http_adapter.post(uri, payload, headers)
    end
  
    def put(uri, payload, headers=nil)
      http_adapter.put(uri, payload, headers)
    end
  
    def delete(uri, headers=nil)
      http_adapter.delete(uri, headers)
    end
  
    def copy(uri, headers)
      http_adapter.copy(uri, headers)
    end    
 
  end
end

HttpAbstraction.extend(RockingChair::HttpAdapter)