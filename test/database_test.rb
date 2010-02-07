require File.dirname(__FILE__) + "/test_helper"

class DatabaseTest < Test::Unit::TestCase
  context "The database engine" do
    setup do
      @db = Fakecouch::Database.new
    end
    
    context "when asking for a UUID" do
      should "return a uuid" do
        assert_not_nil Fakecouch::Database.uuid
      end
      
      should "always return a fresh one" do
        first_id = Fakecouch::Database.uuid
        assert_not_equal first_id, Fakecouch::Database.uuid
      end
      
      should "return a list of UUIDs" do
        assert_equal 3, Fakecouch::Database.uuids(3).uniq.size
      end
    end
    
    context "when storing" do
      should "store an element by id" do
        @db.stubs(:rev).returns('rev')
        @db['abc'] = {:a => :b}.to_json
        assert_equal({'a' => 'b', '_rev' => 'rev', '_id' => 'abc'}, JSON.parse(@db['abc']))
      end
      
      should "assing an ID is none given" do
        @db.stubs(:rev).returns('rev')
        Fakecouch::Database.expects(:uuid).returns('uuid')
        assert_equal( {"rev" => "rev", "id" => "uuid", "ok" => true}, JSON.parse(@db.store(nil, {'a' => 'b'}.to_json)))
      end
      
      should "make sure the content is valid JSON" do
        assert_error_code(500) do
          @db['abc'] = 'string'
        end
      end
      
      should "return the state tuple" do
        @db.expects(:rev).returns('946B7D1C')
        assert_equal({"ok" => true, "id" => "some_doc_id", "rev" => "946B7D1C"}.to_json, @db.store('some_doc_id', {:a => :b}.to_json) )
      end
      
      should "set the id if none given" do
        _id = JSON.parse(@db.store(nil, {:a => :b}.to_json))['_id']
        assert_not_nil JSON.parse(@db[_id])['_id']
      end
      
      should "populate the id" do
        @db['abc'] = {:a => :b}.to_json
        assert_equal 'abc', JSON.parse(@db['abc'])['_id']
      end
      
      should "populate the revision" do
        @db['abc'] = {:a => :b}.to_json
        assert_not_nil JSON.parse(@db['abc'])['_rev']
      end
      
      should "get the document count" do
        assert_equal 0, @db.document_count
        @db['a'] = {:a => :b}.to_json
        assert_equal 1, @db.document_count
        @db['b'] = {:a => :b}.to_json
        assert_equal 2, @db.document_count
        @db['c'] = {:a => :b}.to_json
        assert_equal 3, @db.document_count
      end
      
      context "when updating" do
        should "update the content" do
          state = JSON.parse( @db.store('abc', {:a => :b}.to_json ))
          @db['abc'] = {:a => :c, :_rev => state['rev']}.to_json
          assert_equal 'c', JSON.parse(@db['abc'])['a']
        end
        
        should "raise an error if the revs aren't matching" do
          @db.store('abc', {:a => :b}.to_json )
          assert_error_code(409) do
            @db['abc'] = {:a => :c, :_rev => 'REV'}.to_json
          end
          assert_equal 'b', JSON.parse(@db['abc'])['a']
        end
      end
    end
    
    context "when deleting" do
      setup do
        @state = JSON.parse(@db.store('abc',{:a => :b}.to_json))
      end
      
      should "delete only if the revision matches" do
        assert_error_code 409 do
          @db.delete('abc', 'revrev')
        end
        assert_nothing_raised do
          @db.delete('abc', @state['rev'])
        end
        assert_error_code 404 do
          @db['abc']
        end
      end
    end
    
    context "when copying" do
      setup do
        @state = JSON.parse(@db.store('abc',{:a => :b}.to_json))
      end
      
      should "copy" do
        @db.expects(:rev).returns('355068078')
        @state = JSON.parse(@db.copy('abc', 'def'))
        assert_equal({"ok" => true, "id" => "def", "rev" => "355068078"}, @state)
        assert_equal({'a' => 'b', '_id' => 'def', '_rev' => "355068078"}, JSON.parse(@db['def']))
      end
      
      should "raise 404 if the original if not found" do
        assert_error_code 404 do
          @db.copy('abceeee', 'def')
        end
      end
      
      should "raise 409 if the rev does not match" do
        @state = JSON.parse(@db.store('def',{'1' => '2'}.to_json))
        
        @db.expects(:rev).returns('355068078')
        assert_error_code 409 do
          @db.copy('abc', 'def', 'revrev')
        end
        assert_nothing_raised do
          @db.copy('abc', 'def', @state['rev'])
        end
        assert_equal({'a' => 'b', '_id' => 'def', '_rev' => "355068078"}, JSON.parse(@db['def']))
      end
    end
    
    context "when loading documents by id" do
      should "return the matching document" do
        @db.stubs(:rev).returns('rev')
        @db['a'] = {:a => :b}.to_json
        @db['b'] = {1 => 2}.to_json
        assert_equal({'a' => 'b', '_rev' => 'rev', '_id' => 'a'}, JSON.parse(@db['a']))
      end
      
      should "return a matching document by revision" do
        @db.stubs(:rev).returns('rev')
        @db['a'] = {:a => :b}.to_json
        assert_equal({'a' => 'b', '_rev' => 'rev', '_id' => 'a'}, JSON.parse(@db.load('a', 'rev' => 'rev')))
      end
      
      should "raise a 404 if there is no matching document" do
        assert_error_code(404) do
          @db['no-such-key']
        end
      end
      
      should "raise a 404 if the revision does not match" do
        @db.stubs(:rev).returns('rev')
        @db['a'] = {:a => :b}.to_json
        assert_error_code(404) do
          @db.load('a', 'rev' => 'no-such-rev')
        end
      end
      
      should "load the revision history" do
        @db.stubs(:rev).returns('rev')
        @db['a'] = {:a => :b}.to_json
        assert_equal({'a' => 'b', '_rev' => 'rev', '_id' => 'a', '_revisions' => {'start' => 1, 'ids' => ['rev']}}, JSON.parse(@db.load('a', 'revs' => 'true')))
      end
    end
    
  end
end