require File.dirname(__FILE__) + "/test_helper"

class DatabaseTest < Test::Unit::TestCase
  context "The database engine" do
    setup do
      @db = RockingChair::Database.new
    end
    
    context "when asking for a UUID" do
      should "return a uuid" do
        assert_not_nil RockingChair::Database.uuid
      end
      
      should "always return a fresh one" do
        first_id = RockingChair::Database.uuid
        assert_not_equal first_id, RockingChair::Database.uuid
      end
      
      should "return a list of UUIDs" do
        assert_equal 3, RockingChair::Database.uuids(3).uniq.size
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
        RockingChair::Database.expects(:uuid).returns('uuid')
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
      
      should "raise 409 if no rev given but destination exists" do
        @db.store('destination',{:c => :e}.to_json)
        assert_error_code 409 do
          @db.copy('abc', 'destination')
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
    
    context "when loading all documents" do
      should "return all docs" do
        @db.stubs(:rev).returns('rev')
        5.times do |i|
          @db["item-#{i}"] = {"data" => "item-#{i}"}.to_json
        end
        assert_equal({
          "total_rows" => 5, "offset" => 0, "rows" => [
            {"id" => "item-0", "key" => "item-0", "value" => {"rev" => "rev"}},
            {"id" => "item-1", "key" => "item-1", "value" => {"rev" => "rev"}},
            {"id" => "item-2", "key" => "item-2", "value" => {"rev" => "rev"}},
            {"id" => "item-3", "key" => "item-3", "value" => {"rev" => "rev"}},
            {"id" => "item-4", "key" => "item-4", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents)
      end
      
      should "sort all docs by ID ascending" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 3, "offset" => 0, "rows" => [
            {"id" => "A", "key" => "A", "value" => {"rev" => "rev"}},
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev"}},
            {"id" => "C", "key" => "C", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents)
      end
      
      should "sort all docs by ID descending" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 3, "offset" => 0, "rows" => [
            {"id" => "C", "key" => "C", "value" => {"rev" => "rev"}},
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev"}},
            {"id" => "A", "key" => "A", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents('descending' => true))
      end
      
      should "start by the given key" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 3, "offset" => 0, "rows" => [
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev"}},
            {"id" => "C", "key" => "C", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents('startkey' => 'B'))
      end
      
      should "start by the given key and ignore quotes" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 3, "offset" => 0, "rows" => [
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev"}},
            {"id" => "C", "key" => "C", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents('startkey' => '"B"'))
      end
      
      should "combine start and limit" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        @db["D"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 4, "offset" => 0, "rows" => [
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents('startkey' => 'B', 'limit' => '1'))
      end
      
      should "combine start and descending" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        @db["D"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 4, "offset" => 0, "rows" => [
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev"}},
            {"id" => "A", "key" => "A", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents('startkey' => "B\u999", 'endkey' => "A", 'descending' => 'true'))
      end
      
      should "combine start, limit, and descending" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        @db["D"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 4, "offset" => 0, "rows" => [
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents('startkey' => "B\u999", 'endkey' => "B", 'descending' => 'true', 'limit' => '1'))
      end
      
      should "end by the given key" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 3, "offset" => 0, "rows" => [
            {"id" => "A", "key" => "A", "value" => {"rev" => "rev"}},
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents('endkey' => 'B', 'startkey' => 'A'))
      end
      
      should "combine start and end key" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        @db["D"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 4, "offset" => 0, "rows" => [
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev"}},
            {"id" => "C", "key" => "C", "value" => {"rev" => "rev"}}
          ]
        }.to_json, @db.all_documents('startkey' => 'B', 'endkey' => 'C'))
      end
      
      should "combine start, end key, and include_docs" do
        @db.stubs(:rev).returns('rev')
        @db["C"] = {"data" => "Z"}.to_json
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        @db["D"] = {"data" => "Z"}.to_json
        
        assert_equal({
          "total_rows" => 4, "offset" => 0, "rows" => [
            {"id" => "B", "key" => "B", "value" => {"rev" => "rev", '_rev' => 'rev', 'data' => 'Z', '_id' => 'B'}},
            {"id" => "C", "key" => "C", "value" => {"rev" => "rev", '_rev' => 'rev', 'data' => 'Z', '_id' => 'C'}}
          ]
        }.to_json, @db.all_documents('startkey' => 'B', 'endkey' => 'C', 'include_docs' => 'true'))
      end
      
    end
    
    context "when handling bulk updates" do
      setup do
        @db.stubs(:rev).returns('the-revision')
      end
      
      should "insert all documents" do
        RockingChair::Database.stubs(:uuid).returns('foo-id')
        assert_equal 0, @db.document_count
        docs = {'docs' => [{"_id" => 'a', "value" => 1}, {"_id" => 'b', 'value' => 2}, {'value' => 3}]}.to_json
        assert_equal([
          {'id' => 'a', "rev" => 'the-revision'},
          {'id' => 'b', "rev" => 'the-revision'},
          {'id' => 'foo-id', "rev" => 'the-revision'}
        ].to_json, @db.bulk(docs))
      end
      
      should "update documents" do
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        
        docs = {'docs' => [{"_id" => 'A', "data" => 1, '_rev' => 'the-revision'}]}.to_json
        @db.bulk(docs)
        assert_equal({
          '_id' => 'A',
          '_rev' => 'the-revision',
          'data' => 1
        }, JSON.parse(@db['A']))
      end
      
      should "handle conflics gracefully" do
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        
        docs = {'docs' => [{"_id" => 'A', "data" => 1, '_rev' => 'the-revision'}, {"_id" => 'B', "data" => 1, '_rev' => 'no-such-revision'}]}.to_json
        assert_nothing_raised do
          assert_equal([
            {'id' => 'A', "rev" => 'the-revision'},
            {'id' => 'B', "error" => 'conflict', 'reason' => 'Document update conflict.'}
          ].to_json, @db.bulk(docs))
        end
      end
      
      should "delete" do
        @db["A"] = {"data" => "Z"}.to_json
        @db["B"] = {"data" => "Z"}.to_json
        
        docs = {'docs' => [{"_id" => 'A', "data" => 1, '_rev' => 'the-revision'}, {"_id" => 'B', "data" => 1, '_rev' => 'the-revision', '_deleted' => true}]}.to_json
        assert_nothing_raised do
          assert_equal([
            {'id' => 'A', "rev" => 'the-revision'},
            {'id' => 'B', "rev" => 'the-revision'}
          ].to_json, @db.bulk(docs))
        end
      end
    end
    
    context "when handling design documents" do
      context "the design doc itself" do
        should "return a description of the design document" do
          @db.stubs(:rev).returns('rev')
          @db['_design/user'] = {'language' => 'javascript', 'views' => {}}.to_json
        
          assert_equal({'language' => 'javascript', 'views' => {}, '_rev' => 'rev', '_id' => '_design/user'}, JSON.parse(@db['_design/user']))
        end
      
        should "not allow to store invalid design documents" do
          assert_error_code 500 do
            @db['_design/user'] = {'language' => 'javascript', 'huhu' => {}}.to_json
          end
        end
      
        should "return a description of the design document including the views" do
          @db.stubs(:rev).returns('rev')
          @db['_design/user'] = { 'language' => 'javascript', 'views' => {
            'viewname' => {
              'reduce' => nil, 
              'map' => "function(item){emit(item)}"
            }
          }}.to_json
        
          assert_equal({ 'language' => 'javascript', 'views' => {
            'viewname' => {
              'reduce' => nil, 
              'map' => "function(item){emit(item)}"
            }},
            '_id' => '_design/user',
            '_rev' => 'rev'
          }, JSON.parse(@db['_design/user']))
        end
      
        should "raise a 404 if there is no such design document" do
          assert_error_code 404 do
            @db['_design/foo']
          end
        end
      end
      
      
      
    end
  end
end