# encoding: utf-8

module RockingChair
  module Helper
    
    def self.jsonfy_options(options, *keys)
      keys.each do |key|
        options[key] = ActiveSupport::JSON.decode(options[key]) if options[key]
      end
    end
    
    def self.access(attr_name, doc)
      doc.respond_to?(:_document) ? doc._document[attr_name] : doc[attr_name]
    end
    
  end
end