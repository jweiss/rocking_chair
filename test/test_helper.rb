require File.dirname(__FILE__) + "/../lib/fakecouch"

require 'test/unit'
require 'shoulda'
require 'mocha'

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