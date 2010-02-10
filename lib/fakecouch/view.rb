module Fakecouch
  class View
    
    attr_accessor :database, :keys, :options, :ruby_store, :design_document, :design_document_name, :view_name, :view_document
    
    def self.run(database, design_document_name, view_name, options = {})
      raise ArgumentError, "Need a databae, a design_doc_name and a view_name" unless database.present? && design_document_name.present? && view_name.present?
      new(database, design_document_name, view_name, options).filter.render
    end
    
    def self.run_all(database, options = {})
      new(database, :all, :all, options).filter.render_for_all
    end
        
    def initialize(database, design_document_name, view_name, options = {})
      unless design_document_name == :all && view_name == :all
        Fakecouch::Error.raise_404 unless database.exists?("_design/#{design_document_name}")
        @design_document = JSON.parse(database.storage["_design/#{design_document_name}"])
        @view_document = design_document['views'][view_name] || Fakecouch::Error.raise_404
      end
      
      @database = database
      @keys = database.storage.keys
      @design_document_name = design_document_name
      @view_name = view_name
      initialize_ruby_store
      
      @options = {
        'reduce' => false,
        'limit' => nil,
        'key' => nil,
        'descending' => false,
        'include_docs' => false,
        'without_deleted' => false,
        'endkey' => nil,
        'startkey' => nil,
        'endkey_docid' => nil,
        'startkey_docid' => nil
      }.update(options)
      @options.assert_valid_keys('reduce', 'limit', 'key', 'descending', 'include_docs', 'without_deleted', 'endkey', 'startkey', 'endkey_docid', 'startkey_docid')
      Fakecouch::Helper.jsonfy_options(@options, 'key', 'startkey', 'endkey', 'startkey_docid', 'endkey_docid')
      
      normalize_view_name
    end
    
    def filter
      if view_name == :all
        find_all
      elsif match = view_name.match(/\Aall_documents\Z/)
        find_all_by_class
      elsif match = view_name.match(/\Aby_(\w+)\Z/)
        find_by_attribute(match[1])
      elsif match = view_name.match(/\Aassociation_#{design_document_name}_belongs_to_(\w+)\Z/)
        find_belongs_to(match[1])
      else
        raise "Unknown View implementation for view #{view_name.inspect} in design document _design/#{design_document_name}"
      end
      self
    end
    
    def render
      offset = 0
      total_size = keys.size
      filter_by_startkey_docid_and_endkey_docid
      filter_by_limit
      
      if options['reduce'].to_s == 'true'
        { "rows" => [{'key' => options['key'], 'value' => keys.size }]}.to_json
      else
        rows = keys.map do |key|
          document = ruby_store[key]
          if options['include_docs'].to_s == 'true'
            {'id' => Fakecouch::Helper.access('_id', document), 'value' => nil, 'doc' => (document.respond_to?(:_document) ? document._document : document) }.merge(key_description)
          else
            {'id' => Fakecouch::Helper.access('_id', document), 'key' => options['key'], 'value' => nil}.merge(key_description)
          end
        end
        { "total_rows" => total_size, "offset" => offset, "rows" => rows}.to_json
      end
    end
    
    def render_for_all
      offset = filter_by_startkey
      filter_by_endkey
      filter_by_limit
      
      rows = keys.map do |key|
        document = ruby_store[key]
        if options['include_docs'].to_s == 'true'
          {'id' => document['_id'], 'key' => document['_id'], 'value' => document.update('rev' => document['_rev'])}
        else
          {'id' => document['_id'], 'key' => document['_id'], 'value' => {'rev' => document['_rev']}}
        end
      end
      
      { "total_rows" => database.document_count, "offset" => offset, "rows" => rows}.to_json
    end
    
  protected
  
    def find_all
      sort_by_attribute('_id')
    end
  
    def find_all_by_class
      filter_items_without_correct_ruby_class
      filter_deleted_items if options['without_deleted'].to_s == 'true'
    end
  
    def find_belongs_to(belongs_to)      
      filter_items_by_key([foreign_key_id(belongs_to)])
      filter_items_without_correct_ruby_class
      filter_deleted_items if options['without_deleted'].to_s == 'true'
    end
    
    def find_by_attribute(attribute_string)
      attributes = attribute_string.split("_and_")

      filter_items_by_key(attributes)
      filter_items_without_correct_ruby_class
      filter_deleted_items if options['without_deleted'].to_s == 'true'
      sort_by_attribute(attributes.first)
    end
  
    def normalize_view_name
      return if view_name.is_a?(Symbol)
      
      if view_name.match(/_withoutdeleted\Z/) || view_name.match(/_without_deleted\Z/)
        options['without_deleted'] = true
      elsif view_name.match(/_withdeleted\Z/) || view_name.match(/_with_deleted\Z/)
        options['without_deleted'] = false
      else
        options['without_deleted'] = view_document['map'].match(/\"soft\" deleted/) ? true : nil
      end
      @view_name = view_name.gsub(/_withoutdeleted\Z/, '').gsub(/_without_deleted\Z/, '').gsub(/_withdeleted\Z/, '').gsub(/_with_deleted\Z/, '')
    end
    
    def initialize_ruby_store
      @ruby_store = database.storage.dup
      @ruby_store.each{|k,v| ruby_store[k] = JSON.parse(v) }
    end
    
    def filter_items_by_key(attributes)
      if options['startkey']
        filter_items_by_range(attributes)
      else
        filter_items_by_exact_key(attributes)
      end
    end
    
    def filter_items_by_exact_key(attributes)
      filter_keys = options['key'].is_a?(Array) ? options['key'] : [options['key']]
      attributes.each_with_index do |attribute, index|
        filter_items_without_attribute_value(attribute, filter_keys[index])
      end
    end
    
    def filter_items_by_range(attributes)
      start_keys = options['startkey'].is_a?(Array) ? options['startkey'] : [options['startkey']]
      end_keys = options['endkey'].is_a?(Array) ? options['endkey'] : [options['endkey']]
      
      attributes.each_with_index do |attribute, index|
        filter_items_not_in_range(attribute, start_keys[index], end_keys[index])
      end
    end
    
    def filter_items_not_in_range(attribute, start_key, end_key)
      @keys = keys.select do |key| 
        document = ruby_store[key]
        if end_key
          Fakecouch::Helper.access(attribute, document) && (Fakecouch::Helper.access(attribute, document) >= start_key) && (Fakecouch::Helper.access(attribute, document) <= end_key)
        else
          Fakecouch::Helper.access(attribute, document) && (Fakecouch::Helper.access(attribute, document) >= start_key)
        end
      end
    end
    
    def filter_deleted_items
      @keys = keys.delete_if do |key| 
        document = ruby_store[key]
        Fakecouch::Helper.access('deleted_at', document).present?
      end
    end
    
    def sort_by_attribute(attribute)
      attribute ||= '_id'
      @keys = (options['descending'].to_s == 'true') ? 
        keys.sort{|x,y| Fakecouch::Helper.access(attribute, ruby_store[y]) <=> Fakecouch::Helper.access(attribute, ruby_store[x]) } : 
        keys.sort{|x,y| Fakecouch::Helper.access(attribute, ruby_store[x]) <=> Fakecouch::Helper.access(attribute, ruby_store[y]) }
    end
    
    def filter_items_without_attribute_value(attribute, attr_value)
      if attr_value
        @keys = keys.select do |key| 
          document = ruby_store[key]
          if Fakecouch::Helper.access(attribute, document).is_a?(Array)
            Fakecouch::Helper.access(attribute, document).include?(attr_value)
          else
            Fakecouch::Helper.access(attribute, document) == attr_value
          end
        end
      else
        @keys = keys.select do |key| 
          document = ruby_store[key]
          Fakecouch::Helper.access(attribute, document).present?
        end
      end
    end
    
    def filter_items_without_correct_ruby_class
      klass_name = design_document_name.classify
      @keys = keys.select do |key| 
        document = ruby_store[key]
        Fakecouch::Helper.access('ruby_class', document).to_s.classify == klass_name
      end
    end
    
    def filter_by_limit
      if options['limit']
        @keys = keys[0, options['limit'].to_i]
      end
    end
    
    def filter_by_startkey_docid_and_endkey_docid
      if options['startkey_docid'] || options['endkey_docid']
        @keys = keys.select do |key|
          if options['startkey_docid'] && options['endkey_docid']
            ( key >= options['startkey_docid']) && (key <= options['endkey_docid'])
          elsif options['startkey_docid']
            key >= options['startkey_docid']
          else
            key <= options['endkey_docid']
          end
        end
      end
    end
    
    def filter_by_startkey
      offset = 0
      if options['startkey']
        startkey_found = false
        @keys = keys.map do |key|
          if startkey_found || key == options['startkey']
            startkey_found = true
            key
          else
            offset += 1
            nil
          end
        end.compact
      end
      return offset
    end
    
    def filter_by_endkey
      if options['endkey']
        endkey_found = false
        @keys = keys.map do |key|
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
    end
    
    def foreign_key_id(name)
      name.underscore.gsub('/','__').gsub('::','__') + "_id"
    end
    
    def key_description
      description = {'key' => options['key']}
      description = {'startkey' => options['startkey'], 'endkey' => options['endkey']} if options['startkey']
      description.update('startkey_docid' => options['startkey_docid']) if options['startkey_docid']
      description.update('endkey_docid' => options['endkey_docid']) if options['endkey_docid']
      description
    end
    
  end
end