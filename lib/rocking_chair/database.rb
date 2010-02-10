module RockingChair
  class Database
    
    attr_accessor :storage
    
    def initialize
      @storage = {}
    end
    
    def self.uuid
      UUIDTools::UUID.random_create().to_s.gsub('-', '')
    end
    
    def self.uuids(count)
      ids = []
      count.to_i.times {ids << uuid}
      ids
    end
    
    def rev
      self.class.uuid
    end
    
    def exists?(doc_id)
      storage.has_key?(doc_id)
    end
    
    def [](doc_id)
      if exists?(doc_id)
        return storage[doc_id]
      else
        RockingChair::Error.raise_404
      end
    end
    
    def load(doc_id, options = {})
      options = {
        'rev' => nil,
        'revs' => false
      }.update(options)
      options.assert_valid_keys('rev', 'revs', 'revs_info')
      
      document = self[doc_id]
      if options['rev'] && ( JSON.parse(document)['_rev'] != options['rev']) 
        RockingChair::Error.raise_404
      end
      if options['revs'] && options['revs'] == 'true'
        json =  JSON.parse(document)
        json['_revisions'] = {'start' => 1, 'ids' => [json['_rev']]}
        document = json.to_json
      end
      if options['revs_info'] && options['revs_info'] == 'true'
        json =  JSON.parse(document)
        json['_revs_info'] = [{"rev" => json['_rev'], "status" => "disk"}]
        document = json.to_json
      end
      document
    end
    
    def []=(doc_id, document, options ={})
      # options are ignored for now: batch, bulk
      json = nil
      begin
        json = ActiveSupport::JSON.decode(document)
        raise "is not a Hash" unless json.is_a?(Hash)
      rescue Exception => e
        raise RockingChair::Error.new(500, 'InvalidJSON', "the document is not a valid JSON object: #{e}")
      end
      
      if exists?(doc_id)
        update(doc_id, json)
      else
        insert(doc_id, json)
      end
    end
    
    alias_method :store, :[]=
    
    def delete(doc_id, rev)
      if exists?(doc_id)
        existing = self[doc_id]
        if matching_revision?(existing, rev)
          storage.delete(doc_id)
        else
          RockingChair::Error.raise_409
        end
      else
        RockingChair::Error.raise_404
      end
    end
    
    def copy(original_id, new_id, rev=nil)
      original = JSON.parse(self[original_id])
      if rev
        original['_rev'] = rev
      else
        original.delete('_rev')
      end
      
      self.store(new_id, original.to_json)
    end
    
    def bulk(documents)
      documents = JSON.parse(documents)
      response = []
      documents['docs'].each do |doc|
        begin
          if exists?(doc['_id']) && doc['_deleted'].to_s == 'true'
            self.delete(doc['_id'], doc['_rev'])
            state = {'id' => doc['_id'], 'rev' => doc['_rev']}
          else
            state = JSON.parse(self.store(doc['_id'], doc.to_json))
          end
          response << {'id' => state['id'], 'rev' => state['rev']}
        rescue RockingChair::Error => e
           response << {'id' => doc['_id'], 'error' => e.error, 'reason' => e.reason}
        end
      end
      response.to_json
    end
    
    def document_count
      storage.keys.size
    end
    
    def all_documents(options = {})
      View.run_all(self, options)
    end
    
    def view(design_doc_name, view_name, options = {})
      View.run(self, design_doc_name, view_name, options)
    end
    
  protected
  
    def state_tuple(_id, _rev)
      {"ok" => true, "id" =>  _id, "rev" => _rev }.to_json
    end
  
    def update(doc_id, json)
      existing = self[doc_id]
      if matching_revision?(existing, json['_rev'])
        insert(doc_id, json)
      else
        RockingChair::Error.raise_409
      end
    end
  
    def insert(doc_id, json)
      json.delete('_rev')
      json.delete('_id')
      json['_rev'] = rev
      json['_id'] = doc_id || self.class.uuid
      validate_document(json)
      storage[doc_id] = json.to_json
      
      state_tuple(json['_id'], json['_rev'])
    end
    
    def validate_document(doc)
      if design_doc?(doc)
        RockingChair::Error.raise_500 unless doc['views'].is_a?(Hash)
      end
    end
    
    def design_doc?(doc)
      doc['_id'] && doc['_id'].match(/_design\/[a-zA-Z0-9\_\-]+/)
    end
    
    def matching_revision?(existing_record, rev)
      document = JSON.parse(existing_record)
      RockingChair::Helper.access('_rev', document) == rev
    end
        
  end
end