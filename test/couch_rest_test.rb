require File.dirname(__FILE__) + "/test_helper"

class CouchRestTest < Test::Unit::TestCase
  context "The HTTP Apdapter for CouchRest" do
    setup do
      Fakecouch::Server.reset
      @couch = CouchRest.new("http://127.0.0.1:5984")
    end
    
    context "Database API" do

      should "return the info JSON" do
        assert_equal({"couchdb" => "Welcome","version" => "0.10.1"}, @couch.info)
      end
      
      should "return a list of all databases" do
        assert_equal [], @couch.databases
        @couch.create_db('database-name')
        assert_equal ['database-name'], @couch.databases
      end
      
      should "create a database" do
        db = @couch.create_db('database-name')
      end
      
      should "return information on a database" do
        @couch.create_db('database-name')
        assert_equal({
          "db_name" => "database-name",
          "doc_count" => 0,
          "doc_del_count" => 0,
          "update_seq" => 10,
          "purge_seq" => 0,
          "compact_running" => false,
          "disk_size" => 16473,
          "instance_start_time" => "1265409273572320",
          "disk_format_version" => 4}, @couch.database('database-name').info)
      end
      
      should "delete a database" do
        db = @couch.database('database-name')
        db.delete!
      end
      
    end
    
    context "when asking for UUIDs" do      
      should "return a UUID" do
        Fakecouch::Database.expects(:uuids).with('2').returns(['1', '2'])
        assert_equal '2', @couch.next_uuid(2)
      end
    end
    
    context "Bulk Document API" do
      setup do
        @db = @couch.create_db('fakecouch')
        Fakecouch::Database.any_instance.stubs(:rev).returns('the-revision')
      end
      
      context "loading all documents" do
        should "load the total documents" do
          5.times do |i|
            @db.save_doc({'_id' => "item-#{i}", 'a' => 'b'})
          end
          assert_equal({
            "total_rows" => 5, "offset" => 0, "rows" => [
              {"id" => "item-0", "key" => "item-0", "value" => {"rev" => "the-revision"}},
              {"id" => "item-1", "key" => "item-1", "value" => {"rev" => "the-revision"}},
              {"id" => "item-2", "key" => "item-2", "value" => {"rev" => "the-revision"}},
              {"id" => "item-3", "key" => "item-3", "value" => {"rev" => "the-revision"}},
              {"id" => "item-4", "key" => "item-4", "value" => {"rev" => "the-revision"}}
            ]
          }, @db.documents)
        end
        
        should "sort the result by ID ascending" do
          @db.save_doc({'_id' => "C", 'a' => 'b'})
          @db.save_doc({'_id' => "B", 'a' => 'b'})
          @db.save_doc({'_id' => "A", 'a' => 'b'})
          assert_equal({
            "total_rows" => 3, "offset" => 0, "rows" => [
              {"id" => "A", "key" => "A", "value" => {"rev" => "the-revision"}},
              {"id" => "B", "key" => "B", "value" => {"rev" => "the-revision"}},
              {"id" => "C", "key" => "C", "value" => {"rev" => "the-revision"}}
            ]
          }, @db.documents)
        end
        
        should "sort the result by ID descending" do
          @db.save_doc({'_id' => "C", 'a' => 'b'})
          @db.save_doc({'_id' => "B", 'a' => 'b'})
          @db.save_doc({'_id' => "A", 'a' => 'b'})
          assert_equal({
            "total_rows" => 3, "offset" => 0, "rows" => [
              {"id" => "C", "key" => "C", "value" => {"rev" => "the-revision"}},
              {"id" => "B", "key" => "B", "value" => {"rev" => "the-revision"}},
              {"id" => "A", "key" => "A", "value" => {"rev" => "the-revision"}}
            ]
          }, @db.documents('descending' => true))
        end
        
        should "start by the given key" do
          @db.save_doc({'_id' => "C", 'a' => 'b'})
          @db.save_doc({'_id' => "B", 'a' => 'b'})
          @db.save_doc({'_id' => "A", 'a' => 'b'})
          
          assert_equal({
            "total_rows" => 3, "offset" => 1, "rows" => [
              {"id" => "B", "key" => "B", "value" => {"rev" => "the-revision"}},
              {"id" => "C", "key" => "C", "value" => {"rev" => "the-revision"}}
            ]
          }, @db.documents(:startkey => 'B'))
        end
        
        should "start by the given key, include docs, descending and limit" do
          @db.save_doc({'_id' => "C", 'a' => 'b'})
          @db.save_doc({'_id' => "B", 'a' => 'b'})
          @db.save_doc({'_id' => "A", 'a' => 'b'})
          @db.save_doc({'_id' => "D", 'a' => 'b'})
          
          assert_equal({
            "total_rows" => 4, "offset" => 1, "rows" => [
              {"id" => "C", "key" => "C", "value" => {"rev" => "the-revision", '_rev' => 'the-revision', '_id' => 'C', 'a' => 'b'}},
              {"id" => "B", "key" => "B", "value" => {"rev" => "the-revision", '_rev' => 'the-revision', '_id' => 'B', 'a' => 'b'}}
            ]
          }, @db.documents(:startkey => 'C', :limit => 2, :include_docs => true, :descending => true))
        end
      end
      
      # should "accept bulk inserts/updates" do
      #   @db.bulk_save_cache_limit = 5
      #   assert_nothing_raised do
      #     10.times do |i|
      #       @db.save_doc({'_id' => "new-item-#{i}", 'content' => 'here'}, true)
      #     end
      #   end
      #   assert_equal 10, @db.info['doc_count']
      # end
    end
    
    context "Document API" do
      setup do
        @db = @couch.create_db('fakecouch')
        Fakecouch::Database.any_instance.stubs(:rev).returns('the-revision')
      end

      context "when retrieving a document (GET)" do
        setup do
          @db.save_doc({'_id' => 'the-doc-id', 'a' => 'b'})
        end
        
        should "load the document" do
          assert_equal({"_id" => "the-doc-id","a" => "b", '_rev' => 'the-revision'}, @db.get('the-doc-id'))
        end
        
        should "raise a 404 if the document does not exist" do
          assert_raise(RestClient::ResourceNotFound) do
            @db.get('no-such-id')
          end
        end
        
        should "load the document by a specific revision" do
          assert_equal({"_id" => "the-doc-id","a" => "b", '_rev' => 'the-revision'}, @db.get('the-doc-id', :rev => 'the-revision'))
        end
        
        should "raise a 404 if the revision is not there" do
          assert_raise(RestClient::ResourceNotFound) do
            @db.get('the-doc-id', :rev => 'non-existant-revision')
          end
        end
        
        should "load the document witht the revisions history" do
          assert_equal({"_id" => "the-doc-id","a" => "b", '_rev' => 'the-revision', "_revisions" => {"start" => 1,"ids" => ["the-revision"]}}, @db.get('the-doc-id', :revs => 'true'))
        end
        
        should "load the document witht the detailed revisions history" do
          assert_equal({"_id" => "the-doc-id","a" => "b", '_rev' => 'the-revision', "_revs_info" => [{"rev" => "the-revision", "status" => "disk"}]}, @db.get('the-doc-id', :revs_info => 'true'))
        end
      end
      
      context "when storing a document (PUT)" do
        should "store a new the document" do
          assert_equal 0, @db.info['doc_count']
          @db.save_doc({'_id' => 'new-item', 'content' => 'here'})
          assert_equal 1, @db.info['doc_count']
          assert_equal({"_id" => "new-item","content" => "here", '_rev' => 'the-revision'}, @db.get('new-item'))
        end
        
        should "update a document" do
          seq = sequence('revision')
          Fakecouch::Database.any_instance.expects(:rev).returns('first-rev').in_sequence(seq)
          Fakecouch::Database.any_instance.expects(:rev).returns('second-rev').in_sequence(seq)
          
          @db.save_doc({'_id' => 'new-item', 'content' => 'here'})
          @db.save_doc({'_id' => 'new-item', 'content' => 'better', '_rev' => 'first-rev'})
          
          assert_equal({"_id" => "new-item","content" => "better", '_rev' => 'second-rev'}, @db.get('new-item'))
        end
        
        should "raise 409 on a revision conflict" do
          @db.save_doc({'_id' => 'new-item', 'content' => 'here'})
          assert_raise(HttpAbstraction::Conflict) do
            @db.save_doc({'_id' => 'new-item', 'content' => 'better', '_rev' => 'wrong-revision'})
          end
          
          assert_equal({"_id" => "new-item","content" => "here", '_rev' => 'the-revision'}, @db.get('new-item'))
        end
        
        should "ignore the batch parameter" do
          assert_nothing_raised do
            @db.save_doc({'_id' => 'new-item', 'content' => 'here'}, false, true)
          end
          assert_equal({"_id" => "new-item","content" => "here", '_rev' => 'the-revision'}, @db.get('new-item'))
        end
        
      end
      
      context "when storing a document (POST)" do
        should "store a new the document" do
          Fakecouch::Database.expects(:uuid).returns('5')
          assert_equal 0, @db.info['doc_count']
          assert_equal({"rev"=>"the-revision", "id"=>"5", "ok"=>true}, 
                       CouchRest.post(Fakecouch::Server::BASE_URL + 'fakecouch/', {'content' => 'here'}))
          assert_equal 1, @db.info['doc_count']
        end
      end
      
      context "when deleting a document (DELETE)" do
        should "delete if the rev matches" do
          Fakecouch::Database.any_instance.stubs(:rev).returns('123')
          
          @db.save_doc({'a' => 'b', '_id' => 'delete_me'})
          @db.delete_doc({'a' => 'b', '_id' => 'delete_me', '_rev' => '123'})
          assert_raise(RestClient::ResourceNotFound) do
            @db.get('delete_me')
          end
        end
        
        should "fail with conflich if the rev does not matche" do
          @db.save_doc({'a' => 'b', '_id' => 'delete_me'})
          assert_raise(HttpAbstraction::Conflict) do
            @db.delete_doc({'a' => 'b', '_id' => 'delete_me', '_rev' => 'wrong-revision'})
          end
          assert_nothing_raised do
            @db.get('delete_me')
          end
        end
      end
      
      context "when copying a document (COPY)" do
        setup do
          Fakecouch::Database.any_instance.stubs(:rev).returns('123')
          @db.save_doc({'a' => 'b', '_id' => 'original'})
        end
        
        context "when using an destination ID" do
        
          should "copy" do
            @db.copy_doc({'a' => 'b', '_id' => 'original', '_rev' => '123'}, 'the_new_id')
            assert_equal({'a' => 'b', '_id' => 'the_new_id', '_rev' => '123'}, @db.get('the_new_id'))
          end
        
          should "copy with overwrite with revision" do
            seq = sequence('revision')
            Fakecouch::Database.any_instance.expects(:rev).returns('first-rev').in_sequence(seq)
            Fakecouch::Database.any_instance.expects(:rev).returns('second-rev').in_sequence(seq)
          
            @db.save_doc({'1' => '2', '_id' => 'destination'})
          
            @db.copy_doc({'a' => 'b', '_id' => 'original', '_rev' => '123'}, "destination?rev=first-rev")
            assert_equal({'a' => 'b', '_id' => 'destination', '_rev' => 'second-rev'}, @db.get('destination'))
          end
        
          should "not copy with overwrite if the revision does not match" do
            @db.save_doc({'1' => '2', '_id' => 'destination'})
            assert_raise(HttpAbstraction::Conflict) do
              @db.copy_doc({'a' => 'b', '_id' => 'original', '_rev' => '123'}, 'destination?rev=not-here')
            end
          end
        
        end
        
        context "when using a destination object" do
          should "copy" do
            destination = {"_id" => 'destination', 'c' => 'a', '_rev' => '123'}
            @db.copy_doc({'a' => 'b', '_id' => 'original', '_rev' => '123'}, destination)
            assert_equal({'a' => 'b', '_id' => 'destination', '_rev' => '123'}, @db.get('destination'))
          end
          
          should "copy with overwrite with revision" do
            seq = sequence('revision')
            Fakecouch::Database.any_instance.expects(:rev).returns('first-rev').in_sequence(seq)
            Fakecouch::Database.any_instance.expects(:rev).returns('second-rev').in_sequence(seq)
          
            @db.save_doc({'1' => '2', '_id' => 'destination'})
          
            @db.copy_doc({'a' => 'b', '_id' => 'original', '_rev' => '123'}, {'1' => '2', '_id' => 'destination', '_rev' => 'first-rev'})
            assert_equal({'a' => 'b', '_id' => 'destination', '_rev' => 'second-rev'}, @db.get('destination'))
          end
          
          should "not copy with overwrite if the revision does not match" do
            @db.save_doc({'1' => '2', '_id' => 'destination'})
            assert_raise(HttpAbstraction::Conflict) do
              @db.copy_doc({'a' => 'b', '_id' => 'original', '_rev' => '123'}, {'1' => '2', '_id' => 'destination', '_rev' => 'missing'})
            end
          end
        end
      end
      
    end
     
  end
end