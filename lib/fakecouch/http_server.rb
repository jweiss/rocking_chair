module Fakecouch
  module HttpServer
    BASE_URL = "http://127.0.0.1:5984/"
    
    @databases = {}
    
    def self.reset
      @databases = {}
    end
        
    def self.normalize_url(url)
      url.gsub(BASE_URL, '').gsub('%2F', '/')
    end
    
    def self.info
      respond_with({"couchdb" => "Welcome","version" => "0.10.1"})
    end
    
    def self.all_dbs
      respond_with(@databases.keys)
    end
    
    def self.create_db(name)
      @databases[name] = Fakecouch::Database.new
      respond_with({"ok" => true})
    end
    
    def self.delete_db(name)
      @databases.delete(name)
      respond_with({"ok" => true})
    end
    
    def self.database(name)
      if @databases.has_key?(name)
        respond_with({
          "db_name" => name,
          "doc_count" => @databases[name].document_count,
          "doc_del_count" => 0,
          "update_seq" => 10,
          "purge_seq" => 0,
          "compact_running" => false,
          "disk_size" => 16473,
          "instance_start_time" => "1265409273572320",
          "disk_format_version" => 4})
      else
        respond_with_error(404)
      end
    end
    
    def self.respond_with(obj)
      JSON.generate(obj)
    end
    
    def self.respond_with_error(code, message)
      JSON.generate(code => message)
    end
  end
end