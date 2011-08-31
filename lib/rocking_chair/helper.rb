# encoding: utf-8

module RockingChair
  module Helper

    def self.jsonfy_options(options, *keys)
      keys.each do |key|
        options[key] = json_content(options[key]) if options[key]
      end
    end

    def self.access(attr_name, doc)
      doc.respond_to?(:_document) ? doc._document[attr_name] : doc[attr_name]
    end

    def self.json_content(string)
      if string && string.size < 2 # just one character --> only hashes and arrays are valid root objects
        fixed_json_content(string)
      elsif string == 'null'
        nil
      elsif string
        ActiveSupport::JSON.decode(string)
      else
        nil
      end
    rescue JSON::ParserError, MultiJson::DecodeError
      # probably: only hashes and arrays are valid root objects --> try to fix
      fixed_json_content(string)
    end

    def self.fixed_json_content(string)
      # wrap content in array, then parse and return first value
      ActiveSupport::JSON.decode("[#{string}]")[0]
    end

  end
end