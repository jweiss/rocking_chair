require File.dirname(__FILE__) + "/test_helper"

class CouchRestTest < Test::Unit::TestCase
  context "The HTTP Apdapter for CouchRest" do
    setup do
      @db = CouchRest.new
    end
    
    should "return the info JSON" do
      assert_equal({"couchdb" => "Welcome","version" => "0.10.1"}, @db.info)
    end
    
    context "manipulating complete databases" do
      setup do
        @couch = CouchRest.new("http://127.0.0.1:5984")
        Fakecouch::HttpServer.reset
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
  end
end