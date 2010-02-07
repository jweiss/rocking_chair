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
    
    context "Document API" do

      context "when retrieving a document (GET)" do
        setup do
          @db = @couch.create_db('fakecouch')
        end
        
        should "load the document" do
          Fakecouch::Database.any_instance.stubs(:rev).returns('the-revision')
          @db.save_doc({'_id' => 'the-doc-id', 'a' => 'b'})
          assert_equal({"_id" => "the-doc-id","a" => "b", '_rev' => 'the-revision'}, @db.get('the-doc-id'))
        end
        
        should "raise a 404 if the document does not exist" do
          assert_raise(RestClient::ResourceNotFound) do
            @db.get('no-such-id')
          end
        end
        
        should "load the document by a specific revision" do
          Fakecouch::Database.any_instance.stubs(:rev).returns('the-revision')
          @db.save_doc({'_id' => 'the-doc-id', 'a' => 'b'})
          assert_equal({"_id" => "the-doc-id","a" => "b", '_rev' => 'the-revision'}, @db.get('the-doc-id', :rev => 'the-revision'))
        end
        
        should "raise a 404 if the revision is not there" do
          Fakecouch::Database.any_instance.stubs(:rev).returns('the-revision')
          @db.save_doc({'_id' => 'the-doc-id', 'a' => 'b'})
          assert_raise(RestClient::ResourceNotFound) do
            @db.get('the-doc-id', :rev => 'non-existant-revision')
          end
        end
        
        should "load the document witht the revisions history" do
          Fakecouch::Database.any_instance.stubs(:rev).returns('the-revision')
          @db.save_doc({'_id' => 'the-doc-id', 'a' => 'b'})
          assert_equal({"_id" => "the-doc-id","a" => "b", '_rev' => 'the-revision', "_revisions" => {"start" => 1,"ids" => ["the-revision"]}}, @db.get('the-doc-id', :revs => 'true'))
        end
        
        should "load the document witht the detailed revisions history" do
          Fakecouch::Database.any_instance.stubs(:rev).returns('the-revision')
          @db.save_doc({'_id' => 'the-doc-id', 'a' => 'b'})
          assert_equal({"_id" => "the-doc-id","a" => "b", '_rev' => 'the-revision', "_revs_info" => [{"rev" => "the-revision", "status" => "disk"}]}, @db.get('the-doc-id', :revs_info => 'true'))
        end
      end
      
      
    end
     
  end
end