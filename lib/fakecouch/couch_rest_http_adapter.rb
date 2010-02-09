module Fakecouch
  module CouchRestHttpAdapter
    URL_PARAMETER = /[a-zA-Z0-9\-\_\%]+/
    
    @_fakecouch_debug = true
    
    def get(uri, headers={})
      puts "GET: #{uri.inspect}: #{headers.inspect}" if @_fakecouch_debug
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url == ''
        Fakecouch::Server.info
      elsif url == '_all_dbs'
        Fakecouch::Server.all_dbs(parameters)
      elsif url == '_uuids'
        Fakecouch::Server.uuids(parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.database($1, parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\/_all_docs\Z/)
        Fakecouch::Server.load_all($1, parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.load($1, $2, parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\/_design\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.load($1, "_design/#{$2}", parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\/_design\/(#{URL_PARAMETER})\/_view\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.view($1, $2, $3, parameters)
      else
        raise "GET: Unknown url: #{url.inspect}  headers: #{headers.inspect}"
      end
    end
  
    def post(uri, payload, headers={})
      puts "POST: #{uri.inspect}: #{payload.inspect} #{headers.inspect}" if @_fakecouch_debug
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url.match(/\A(#{URL_PARAMETER})\/?\Z/)
        Fakecouch::Server.store($1, nil, payload, parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/) && $2 == '_bulk_docs'
        Fakecouch::Server.bulk($1, payload)
      else
        raise "POST: Unknown url: #{uri.inspect}: #{payload.inspect} #{headers.inspect}" 
      end
    end
  
    def put(uri, payload, headers={})
      puts "PUT: #{uri.inspect}: #{payload.inspect} #{headers.inspect}" if @_fakecouch_debug
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url.match(/\A(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.create_db(url)
      elsif url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.store($1, $2, payload, parameters)
      elsif url.match(/\A(#{URL_PARAMETER})\/_design\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.store($1, "_design/#{$2}", payload, parameters)
      else
        raise "PUT: Unknown url: #{uri.inspect}: #{payload.inspect} #{headers.inspect}" 
      end
    end
  
    def delete(uri, headers={})
      puts "DELETE: #{uri.inspect}: #{headers.inspect}" if @_fakecouch_debug
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url.match(/\A(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.delete_db(url)
      elsif url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.delete($1, $2, parameters)
      else
        raise "DELETE: Unknown url: #{uri.inspect}: #{headers.inspect}"
      end
    end
  
    def copy(uri, headers)
      puts "COPY: #{uri.inspect}: #{headers.inspect}" if @_fakecouch_debug
      url, parameters = Fakecouch::Server.normalize_url(uri)
      if url.match(/\A(#{URL_PARAMETER})\/(#{URL_PARAMETER})\Z/)
        Fakecouch::Server.copy($1, $2, headers.merge(parameters))
      else
        raise "COPY: Unknown url: #{uri.inspect}: #{headers.inspect}"
      end
    end
    
  end
end