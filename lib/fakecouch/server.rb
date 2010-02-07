module Fakecouch
  module Server
    BASE_URL = "http://127.0.0.1:5984/"
    
    def self.databases
      @databases ||= {}
    end
    
    def self.reset
      @databases = {}
    end
    
    def self.normalize_options(options)
      (options || {}).each do |k,v|
        options[k] = options[k].first if options[k].is_a?(Array)
      end
      options
    end
        
    def self.normalize_url(url)
      url = url.to_s.gsub(BASE_URL, '') #.gsub('%2F', '/')
      if url.match(/\A(.*)\?(.*)?\Z/)
        return [$1, normalize_options(CGI::parse($2 || ''))]
      else
        return [url, {}]
      end
    end
    
    def self.info
      respond_with({"couchdb" => "Welcome","version" => "0.10.1"})
    end
    
    def self.all_dbs(options = {})
      respond_with(databases.keys)
    end
    
    def self.uuids(options = {})
      options = {
        'count' => 100
      }.update(options)
      options['count'] = options['count'].first if options['count'].is_a?(Array)

      respond_with({"uuids" => Fakecouch::Database.uuids(options['count']) })
    end
    
    def self.create_db(name)
      databases[name] = Fakecouch::Database.new
      respond_with({"ok" => true})
    end
    
    def self.delete_db(name)
      databases.delete(name)
      respond_with({"ok" => true})
    end
    
    def self.store(db_name, doc_id, document, options)
      respond_with_error(404) unless databases.has_key?(db_name)
      databases[db_name].store(doc_id, document, options)
    rescue Fakecouch::Error => e
      e.raise_rest_client_error
    end
    
    def self.delete(db_name, doc_id, options = {})
      options = {
        'rev' => nil
      }.update(options)
      options['rev'] = options['rev'].first if options['rev'].is_a?(Array)
      
      respond_with_error(404) unless databases.has_key?(db_name)
      databases[db_name].delete(doc_id, options['rev'])
    rescue Fakecouch::Error => e
      e.raise_rest_client_error
    end
    
    def self.load(db_name, doc_id, options = {})
      respond_with_error(404) unless databases.has_key?(db_name)
      databases[db_name].load(doc_id, options)
    rescue Fakecouch::Error => e
      e.raise_rest_client_error
    end
    
    def self.load_all(db_name, options = {})
      respond_with_error(404) unless databases.has_key?(db_name)
      databases[db_name].all_documents(options)
    rescue Fakecouch::Error => e
      e.raise_rest_client_error
    end
    
    def self.copy(db_name, doc_id, options = {})
      respond_with_error(404) unless databases.has_key?(db_name)
      destination_id, revision = normalize_url(options['Destination'])
      databases[db_name].copy(doc_id, destination_id, revision['rev'])
    rescue Fakecouch::Error => e
      e.raise_rest_client_error
    end
    
    def self.database(name, parameters)
      if databases.has_key?(name)
        respond_with({
          "db_name" => name,
          "doc_count" => databases[name].document_count,
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
      obj.to_json
    end
    
    def self.respond_with_error(code, message)
      {code => message}.to_json
    end
  end
end