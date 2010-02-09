require File.dirname(__FILE__) + "/../lib/fakecouch"

require 'test/unit'
require 'shoulda'
require 'mocha'

require File.dirname(__FILE__) + "/fixtures/extended_couch_rest_fixtures"
require File.dirname(__FILE__) + "/fixtures/simply_stored_fixtures"

Fakecouch.enable

def assert_error_code(code, &blk)
  ex = nil
  begin
    blk.call
  rescue Exception => e
    ex = e
  ensure
    assert_not_nil ex, "No Exception raised!"
    assert_equal Fakecouch::Error, ex.class, "The raised exception is not a Fakecouch::Error: #{e.class}: #{e.message} - #{e.backtrace.join("\n")}"
    assert_equal code, ex.code
  end
end

def dump_fakecouch
  puts "No datases set yet!" if Fakecouch::Server.databases.empty?
  Fakecouch::Server.databases.each do |db_name, db|
    puts "Content of Database #{db_name}: \n\n#{db.inspect}"
  end
end

def with_debug(&blk)
  HttpAbstraction.instance_variable_set("@_fakecouch_debug", true)
  blk.call
  HttpAbstraction.instance_variable_set("@_fakecouch_debug", false)
end