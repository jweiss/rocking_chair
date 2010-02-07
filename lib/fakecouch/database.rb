module Fakecouch
  class Database
    
    attr_accessor :storage
    
    def initialize
      @storage = {}
    end
    
    def self.uuid
      UUIDTools::UUID.random_create().to_s
    end
    
    def self.uuids(count)
      ids = []
      count.to_i.times {ids << uuid}
      ids
    end
    
    def rev
      self.class.uuid
    end
    
    def [](doc_id)
      if exists?(doc_id)
        return storage[doc_id]
      else
        raise_404
      end
    end
    
    def load(doc_id, options = {})
      options = {
        'rev' => nil,
        'revs' => false
      }.update(options)
      options.assert_valid_keys('rev', 'revs', 'revs_info')
      
      document = self[doc_id]
      if options['rev'] && ( ActiveSupport::JSON.decode(document)['_rev'] != options['rev']) 
        raise_404
      end
      if options['revs'] && options['revs'] == 'true'
        json =  ActiveSupport::JSON.decode(document)
        json['_revisions'] = {'start' => 1, 'ids' => [json['_rev']]}
        document = json.to_json
      end
      if options['revs_info'] && options['revs_info'] == 'true'
        json =  ActiveSupport::JSON.decode(document)
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
        raise Fakecouch::Error.new(500, 'InvalidJSON', "the document is not a valid JSON object: #{e}")
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
          raise_409
        end
      else
        raise_404(doc_id)
      end
    end
    
    def copy(original_id, new_id, rev=nil)
      original = JSON.parse(self[original_id])
      if rev
        original['_rev'] = rev
      else
        original.delete('_rev')
      end
      original.delete('_id')
      
      self.store(new_id, original.to_json)
    end
    
    def document_count
      storage.keys.size
    end

  protected
  
    def exists?(doc_id)
      storage.has_key?(doc_id)
    end
  
    def raise_404
      raise Fakecouch::Error.new(404, 'not_found', "missing")
    end
    
    def raise_409
      raise Fakecouch::Error.new(409, 'conflict', "Document update conflict.")
    end
  
    def state_tuple(_id, _rev)
      {"ok" => true, "id" =>  _id, "rev" => _rev }.to_json
    end
  
    def update(doc_id, json)
      existing = self[doc_id]
      if matching_revision?(existing, json['_rev'])
        insert(doc_id, json)
      else
        raise_409
      end
    end
  
    def insert(doc_id, json)
      json.delete('_rev')
      json.delete('_id')
      json[:_rev] = rev
      json[:_id] = doc_id || self.class.uuid
      
      storage[doc_id] = json.to_json
      
      state_tuple(json[:_id], json[:_rev])
    end
    
    def matching_revision?(existing_record, rev)
      JSON.parse(existing_record)['_rev'] == rev
    end
    
  end
end