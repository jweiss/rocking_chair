module Fakecouch
  class Database
    
    attr_accessor :storage
    
    def initialize
      @storage = {}
    end
    
    def uuid
      UUIDTools::UUID.random_create().to_s
    end
    alias rev uuid
    
    def [](doc_id)
      if exists?(doc_id)
        return storage[doc_id]
      else
        raise_404(doc_id)
      end
    end
    
    def []=(doc_id, document)
      json = nil
      begin
        json = JSON.parse(document)
      rescue JSON::ParserError => e
        raise Fakecouch::Error.new(500, 'InvalidJSON', "the document is not a valid JSON object: #{e}")
      end
      
      if exists?(doc_id)
        update(doc_id, json)
      else
        insert(doc_id, json)
      end
    end
    
    alias_method :store, :[]=
    
    def delete(doc_id, rev=nil)
      if exists?(doc_id)
        if rev
          existing = self[doc_id]
          if matching_revision?(existing, rev)
            storage.delete(doc_id)
          else
            raise_409
          end
        else
          storage.delete(doc_id)
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
      
      self.store(new_id, JSON.generate(original))
    end

  protected
  
    def exists?(doc_id)
      storage.has_key?(doc_id)
    end
  
    def raise_404(doc_id)
      raise Fakecouch::Error.new(404, 'DocumentNotFound', "could not find a document by ID #{doc_id.inspect}")
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
      json[:_id] = doc_id || uuid
      
      storage[doc_id] = JSON.generate(json)
      
      state_tuple(json[:_id], json[:_rev])
    end
    
    def matching_revision?(existing_record, rev)
      JSON.parse(existing_record)['_rev'] == rev
    end
    
  end
end