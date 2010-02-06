module Fakecouch
  module CouchRestHttpAdapter
    
    def get(uri, headers={})
      url = Fakecouch::HttpServer.normalize_url(uri)
      if url == ''
        Fakecouch::HttpServer.info
      elsif url == '_all_dbs'
        Fakecouch::HttpServer.all_dbs
      elsif url.match(/\A[a-zA-Z0-9\-\_\%]+\Z/)
        Fakecouch::HttpServer.database(url)
      else
        raise "GET: Unknown url: #{url.inspect}  headers: #{headers.inspect}"
      end
    end
  
    def post(uri, payload, headers={})
      raise "POST: #{uri.inspect}: #{payload.inspect} #{headers.inspect}" 
    end
  
    def put(uri, payload, headers={})
      url = Fakecouch::HttpServer.normalize_url(uri)
      if url.match(/\A[a-zA-Z0-9\-\_\%]+\Z/)
        Fakecouch::HttpServer.create_db(url)
      else
        raise "PUT: #{uri.inspect}: #{payload.inspect} #{headers.inspect}" 
      end
    end
  
    def delete(uri, headers={})
      url = Fakecouch::HttpServer.normalize_url(uri)
      if url.match(/\A[a-zA-Z0-9\-\_\%]+\Z/)
        Fakecouch::HttpServer.delete_db(url)
      else
        raise "DELETE: #{uri.inspect}: #{headers.inspect}" 
      end
    end
  
    def copy(uri, headers)
      raise "COPY: #{uri.inspect}: #{headers.inspect}" 
    end
    
  end
end

HttpAbstraction.extend(Fakecouch::CouchRestHttpAdapter)