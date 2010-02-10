module Fakecouch
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
        Fakecouch::Error.raise_404
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
        Fakecouch::Error.raise_404
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
          Fakecouch::Error.raise_409
        end
      else
        Fakecouch::Error.raise_404
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
        rescue Fakecouch::Error => e
           response << {'id' => doc['_id'], 'error' => e.error, 'reason' => e.reason}
        end
      end
      response.to_json
    end
    
    def document_count
      storage.keys.size
    end
    
    def all_documents(options = {})
      options = {
        'descending' => false,
        'startkey' => nil,
        'endkey' => nil,
        'limit' => nil,
        'include_docs' => false
      }.update(options)
      options.assert_valid_keys('descending', 'startkey', 'endkey', 'limit', 'include_docs')
      keys = (options['descending'].to_s == 'true') ? storage.keys.sort{|x,y| y <=> x } : storage.keys.sort{|x,y| x <=> y }
      
      keys, offset = filter_by_startkey(keys, options)
      keys = filter_by_endkey(keys, options)
      keys = filter_by_limit(keys, options)
      
      rows = keys.map do |key|
        document = JSON.parse(storage[key])
        if options['include_docs'].to_s == 'true'
          {'id' => document['_id'], 'key' => document['_id'], 'value' => document.update('rev' => document['_rev'])}
        else
          {'id' => document['_id'], 'key' => document['_id'], 'value' => {'rev' => document['_rev']}}
        end
      end
      
      { "total_rows" => document_count, "offset" => offset, "rows" => rows}.to_json
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
        Fakecouch::Error.raise_409
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
        Fakecouch::Error.raise_500 unless doc['views'].is_a?(Hash)
      end
    end
    
    def design_doc?(doc)
      doc['_id'] && doc['_id'].match(/_design\/[a-zA-Z0-9\_\-]+/)
    end
    
    def matching_revision?(existing_record, rev)
      document = JSON.parse(existing_record)
      attribute_access('_rev', document) == rev
    end
    
    def filter_by_startkey(keys, options)
      offset = 0
      if options['startkey']
        options['startkey'] = options['startkey'].gsub(/\A"/, '').gsub(/"\Z/, '')
        startkey_found = false
        keys = keys.map do |key|
          if startkey_found || key == options['startkey']
            startkey_found = true
            key
          else
            offset += 1
            nil
          end
        end.compact
      end
      return [keys, offset]
    end
    
    def filter_by_endkey(keys, options)
      if options['endkey']
        options['endkey'] = options['endkey'].gsub(/\A"/, '').gsub(/"\Z/, '')
        endkey_found = false
        keys = keys.map do |key|
          if key == options['endkey']
            endkey_found = true
            key
          elsif endkey_found
            nil
          else
            key
          end
        end.compact
      end
      keys
    end
    
    def filter_by_limit(keys, options)
      if options['limit']
        keys = keys[0, options['limit'].to_i]
      end
      keys
    end
    
    def attribute_access(attr_name, doc)
      doc.respond_to?(:_document) ? doc._document[attr_name] : doc[attr_name]
    end
        
  end
end