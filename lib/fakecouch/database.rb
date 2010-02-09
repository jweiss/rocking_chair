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
      raise ArgumentError, "Need design_doc_name and view_name" unless design_doc_name.present? && view_name.present?
      raise_404 unless self.storage["_design/#{design_doc_name}"]
      design_doc = JSON.parse(self.storage["_design/#{design_doc_name}"])
      view_doc = design_doc['views'][view_name] || raise_404
      
      options = {
        'reduce' => false,
        'limit' => nil,
        'key' => nil,
        'descending' => false,
        'include_docs' => false,
        'without_deleted' => false
      }.update(options)
      options.assert_valid_keys('reduce', 'limit', 'key', 'descending', 'include_docs', 'without_deleted')

      if view_name.match(/_withoutdeleted\Z/) || view_name.match(/_without_deleted\Z/)
        options['without_deleted'] = true
      elsif view_name.match(/_withdeleted\Z/) || view_name.match(/_with_deleted\Z/)
        options['without_deleted'] = false
      else
        options['without_deleted'] = view_doc['map'].match(/\"soft\" deleted/) ? true : nil
      end
      view_name = view_name.gsub(/_withoutdeleted\Z/, '').gsub(/_without_deleted\Z/, '').gsub(/_withdeleted\Z/, '').gsub(/_with_deleted\Z/, '')

      if match = view_name.match(/\Aall_documents\Z/)
        find_all(design_doc_name, options)
      elsif match = view_name.match(/\Aby_(\w+)\Z/)
        find_by_attribute(match[1], design_doc_name, options)
      elsif match = view_name.match(/\Aassociation_#{design_doc_name}_belongs_to_(\w+)\Z/)
        find_belongs_to(match[1], design_doc_name, options)
      else
        raise "Unknown View implementation for view #{view_name.inspect} in design document _design/#{design_doc_name}"
      end
    end

  protected
  
    def find_all(design_doc_name, options)
      ruby_store = copy_storage_to_ruby_hash
      keys = ruby_store.keys
      keys = filter_items_without_correct_ruby_class(keys, ruby_store, design_doc_name)
      keys = filter_deleted_items(keys, ruby_store) if options['without_deleted'].to_s == 'true'
      
      view_json(keys, ruby_store, options)
    end
  
    def find_belongs_to(belongs_to, design_doc_name, options)
      options['key'] = ActiveSupport::JSON.decode(options['key']) if options['key']
      
      ruby_store = copy_storage_to_ruby_hash
      keys = ruby_store.keys
      keys = filter_items_without_attribute_value(keys, ruby_store, foreign_key_id(belongs_to), options['key'])
      keys = filter_items_without_correct_ruby_class(keys, ruby_store, design_doc_name)
      keys = filter_deleted_items(keys, ruby_store) if options['without_deleted'].to_s == 'true'

      view_json(keys, ruby_store, options)
    end
  
    def find_by_attribute(attribute_string, design_doc_name, options)
      attributes = attribute_string.split("_and_")
      options['key'] = ActiveSupport::JSON.decode(options['key']) if options['key']
      filter_keys = options['key'].is_a?(Array) ? options['key'] : [options['key']]
      ruby_store = copy_storage_to_ruby_hash

      keys = ruby_store.keys
      attributes.each_with_index do |attribute, index|
        keys = filter_items_without_attribute_value(keys, ruby_store, attribute, filter_keys[index])
      end
      keys = filter_items_without_correct_ruby_class(keys, ruby_store, design_doc_name)
      keys = filter_deleted_items(keys, ruby_store) if options['without_deleted'].to_s == 'true'
      keys = sort_by_attribute(keys, ruby_store, attributes.first, options)
      
      view_json(keys, ruby_store, options)
    end
    
    def filter_deleted_items(keys, collection)
      keys = keys.delete_if do |key| 
        document = collection[key]
        attribute_access('deleted_at', document).present?
      end
    end
    
    def sort_by_attribute(keys, collection, attribute, options)
      keys = (options['descending'].to_s == 'true') ? 
        keys.sort{|x,y| attribute_access(attribute, collection[y]) <=> attribute_access(attribute, collection[x]) } : 
        keys.sort{|x,y| attribute_access(attribute, collection[x]) <=> attribute_access(attribute, collection[y]) }
    end
    
    def attribute_access(attr_name, doc)
      doc.respond_to?(:_document) ? doc._document[attr_name] : doc[attr_name]
    end
    
    def filter_items_without_attribute_value(keys, collection, attribute, attr_value)
      if attr_value
        keys = keys.select do |key| 
          document = collection[key]
          if attribute_access(attribute, document).is_a?(Array)
            attribute_access(attribute, document).include?(attr_value)
          else
            attribute_access(attribute, document) == attr_value
          end
        end
      else
        keys = keys.select do |key| 
          document = collection[key]
          attribute_access(attribute, document).present?
        end
      end
    end
    
    def filter_items_without_correct_ruby_class(keys, collection, klass_name)
      klass_name = klass_name.classify
      keys = keys.select do |key| 
        document = collection[key]
        attribute_access('ruby_class', document).to_s.classify == klass_name
      end
    end
  
    def filter_by_limit(keys, options)
      if options['limit']
        keys = keys[0, options['limit'].to_i]
      end
      keys
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
  
    def exists?(doc_id)
      storage.has_key?(doc_id)
    end
  
    def raise_404
      raise Fakecouch::Error.new(404, 'not_found', "missing")
    end
    
    def raise_409
      raise Fakecouch::Error.new(409, 'conflict', "Document update conflict.")
    end
    
    def raise_500
      raise Fakecouch::Error.new(500, 'invalid', "the document is invalid.")
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
      json['_rev'] = rev
      json['_id'] = doc_id || self.class.uuid
      validate_document(json)
      storage[doc_id] = json.to_json
      
      state_tuple(json['_id'], json['_rev'])
    end
    
    def validate_document(doc)
      if design_doc?(doc)
        raise_500 unless doc['views'].is_a?(Hash)
      end
    end
    
    def design_doc?(doc)
      doc['_id'] && doc['_id'].match(/_design\/[a-zA-Z0-9\_\-]+/)
    end
    
    def matching_revision?(existing_record, rev)
      document = JSON.parse(existing_record)
      attribute_access('_rev', document) == rev
    end
    
    def copy_storage_to_ruby_hash
      ruby_store = storage.dup
      ruby_store.each{|k,v| ruby_store[k] = JSON.parse(v) }
      ruby_store
    end
    
    def foreign_key_id(name)
      name.underscore.gsub('/','__').gsub('::','__') + "_id"
    end
    
    def view_json(keys, collection, options)
      offset = 0
      total_size = keys.size
      keys = keys[0, options['limit'].to_i] if options['limit']
      
      if options['reduce'].to_s == 'true'
        { "rows" => [{'key' => options['key'], 'value' => keys.size }]}.to_json
      else
        rows = keys.map do |key|
          document = collection[key]
          if options['include_docs'].to_s == 'true'
            {'id' => attribute_access('_id', document), 'key' => options['key'], 'value' => nil, 'doc' => (document.respond_to?(:_document) ? document._document : document) }
          else
            {'id' => attribute_access('_id', document), 'key' => options['key'], 'value' => nil}
          end
        end
        { "total_rows" => total_size, "offset" => offset, "rows" => rows}.to_json
      end
    end
    
  end
end