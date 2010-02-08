module Fakecouch
  module CouchRestHttpAdapter
    URL_PARAMETER = /[a-zA-Z0-9\-\_\%]+/
    
    def get(uri, headers={})
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url == ''
        Fakecouch::Server.info
      elsif url == '_all_dbs'
        Fakecouch::Server.all_dbs(parameters)
      elsif url == '_uuids'
        Fakecouch::Server.uuids(parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.database($1, parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/) && $2 == '_all_docs'
        Fakecouch::Server.load_all($1, parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.load($1, $2, parameters)
      else
        raise "GET: Unknown url: #{url.inspect}  headers: #{headers.inspect}"
      end
    end
  
    def post(uri, payload, headers={})
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url.match(/\A(#{URL_PARAMETER})\/?\Z/)
        Fakecouch::Server.store($1, nil, payload, parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/) && $2 == '_bulk_docs'
        Fakecouch::Server.bulk($1, payload)
      else
        raise "POST: #{uri.inspect}: #{payload.inspect} #{headers.inspect}" 
      end
    end
  
    def put(uri, payload, headers={})
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url.match(/\A(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.create_db(url)
      elsif url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.store($1, $2, payload, parameters)
      else
        raise "PUT: #{uri.inspect}: #{payload.inspect} #{headers.inspect}" 
      end
    end
  
    def delete(uri, headers={})
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url.match(/\A(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.delete_db(url)
      elsif url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.delete($1, $2, parameters)
      else
        raise "DELETE: #{uri.inspect}: #{headers.inspect}"
      end
    end
  
    def copy(uri, headers)
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.copy($1, $2, headers.merge(parameters))
      else
        raise "COPY: #{uri.inspect}: #{headers.inspect}"
      end
    end
    
  end
end

HttpAbstraction.extend(Fakecouch::CouchRestHttpAdapter)