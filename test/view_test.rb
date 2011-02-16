require File.dirname(__FILE__) + "/test_helper"

class ViewTest < Test::Unit::TestCase
  context "A database view" do
    setup do
      @db = RockingChair::Database.new
    end
    
    should "need a database, a design doc, and a view name" do
      assert_error_code 404 do
        RockingChair::View.new(@db, 'user', 'by_firstname', {})
      end
      
      @db['_design/user'] = { 'language' => 'javascript', 'views' => {
        'by_firstname' => {
          'reduce' => "function(key, values){ return values.length }",
          "map" => "function(doc) { if(doc.ruby_class && doc.ruby_class == 'Instance') { emit(doc['created_at'], null); } }"
        }
      }}
      
      @db.stubs(:rev).returns('the-rev')
      
      assert_nothing_raised do
        RockingChair::View.new(@db, 'user', 'by_firstname', {})
      end
    end
    
    should "be constructed out a database" do
      @db['_design/user'] = { 'language' => 'javascript', 'views' => {
        'by_firstname' => {
          'reduce' => "function(key, values){ return values.length }",
          "map" => "function(doc) { if(doc.ruby_class && doc.ruby_class == 'Instance') { emit(doc['created_at'], null); } }"
        }
      }}
      
      assert_nothing_raised do
        JSON.parse(@db.view('user', 'by_firstname', {}))
      end
    end
    
    context "when querying the views" do
      setup do
        @db['_design/user'] = { 'language' => 'javascript', 'views' => {
          'all_documents' => {
            'reduce' => nil, 
            'map' => "function(item){emit(item)}"
          },
          'by_firstname' => {
            'reduce' => "_sum",
            "map" => "function(doc) {\n if(doc.ruby_class && doc.ruby_class == 'Instance') {\n emit(doc['created_at'], null);\n }\n }"
          },
          'by_firstname_and_lastname' => {
            'reduce' => "_sum",
            "map" => "function(doc) {\n if(doc.ruby_class && doc.ruby_class == 'Instance') {\n emit(doc['created_at'], null);\n }\n }"
          },
          'association_user_belongs_to_project' => {
            'reduce' => "_sum",
            "map" => "function(doc) {\n if(doc.ruby_class && doc.ruby_class == 'Instance') {\n emit(doc['created_at'], null);\n }\n }"
          },
          'association_user_has_and_belongs_to_many_groups' => {
            'reduce' => "_sum",
            "map" => "function(doc) {\n if(doc.ruby_class && doc.ruby_class == 'Instance') {\n emit(doc['created_at'], null);\n }\n }"
          }
        }}
        
        @db.stubs(:rev).returns('the-rev')
      end
      
      should "respond to defined views" do
        assert_nothing_raised do
          @db.view('user', 'by_firstname', 'key' => 'abc')
        end
      end
      
      should "raise a 404 on undefined views" do
        assert_error_code 404 do
          @db.view('user', 'by_other_name', 'key' => 'abc')
        end
      end
      
      context "when querying by_attr_and_attr views" do
        
        should "return all keys if no key is given" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"firstname" => 'Carl', 'lastname' => 'Alf', 'ruby_class' => 'User'}
          @db['user_3'] = {"firstname" => 'Alf', 'lastname' => 'Horst', 'ruby_class' => 'User'}
          
          assert_equal({
            "total_rows" => 3,
            "offset" => 0,
            "rows" => [{
              "id" => "user_1",
              "key" => nil,
              "value" => nil,
              },{
              "id" => "user_3",
              "key" => nil,
              "value" => nil, 
              },{
              "id" => "user_2",
              "key" => nil,
              "value" => nil
              }
            ]}, JSON.parse(@db.view('user', 'by_firstname')))
        end
        
        should "return all docs if no key is given and we asked to include the docs" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"firstname" => 'Carl', 'lastname' => 'Alf', 'ruby_class' => 'User'}
          @db['user_3'] = {"firstname" => 'Alf', 'lastname' => 'Horst', 'ruby_class' => 'User'}
          
          assert_equal({
            "total_rows" => 3,
            "offset" => 0,
            "rows" => [{
              "id" => "user_1",
              "key" => nil,
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Bert",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_1' }
              },{
              "id" => "user_3",
              "key" => nil,
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Horst",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_3' }
              }, {
              "id" => "user_2",
              "key" => nil,
              "value" => nil,
              "doc" => {
                "firstname" => "Carl",
                "lastname" => "Alf",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_2' }
              }
            ]}.to_json, @db.view('user', 'by_firstname', 'include_docs' => 'true'))
        end
        
        should "return matching elements" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"firstname" => 'Carl', 'lastname' => 'Alf', 'ruby_class' => 'User'}
          @db['user_3'] = {"firstname" => 'Alf', 'lastname' => 'Horst', 'ruby_class' => 'User'}
          
          assert_equal({
            "total_rows" => 2,
            "offset" => 0,
            "rows" => [{
              "id" => "user_1",
              "key" => "Alf",
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Bert",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_1' }
              }, {
              "id" => "user_3",
              "key" => "Alf",
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Horst",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_3' }
              }
            ]}.to_json, @db.view('user', 'by_firstname', 'key' => "Alf".to_json, 'include_docs' => 'true'))
        end
        
        should "only return items with the correct klass matcher" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'Project'}
          @db['user_2'] = {"firstname" => 'Alf', 'lastname' => 'Michaels'}
          @db['user_3'] = {"firstname" => 'Alf', 'lastname' => 'Horst', 'ruby_class' => 'User'}
          
          assert_equal({
            "total_rows" => 1,
            "offset" => 0,
            "rows" => [{
              "id" => "user_3",
              "key" => "Alf",
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Horst",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_3' }
              }
            ]}.to_json, @db.view('user', 'by_firstname', 'key' => "Alf".to_json, 'include_docs' => 'true'))
        end
        
        should "support multiple attributes" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"firstname" => 'Carl', 'lastname' => 'Alf', 'ruby_class' => 'User'}
          @db['user_3'] = {"firstname" => 'Alf', 'lastname' => 'Horst', 'ruby_class' => 'User'}
          
          assert_equal({
            "total_rows" => 1,
            "offset" => 0,
            "rows" => [{
              "id" => "user_1",
              "key" => ["Alf", "Bert"],
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Bert",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_1' }
              }
            ]}.to_json, @db.view('user', 'by_firstname_and_lastname', 'key' => ["Alf", "Bert"].to_json, 'include_docs' => 'true'))
        end

        should "support startkey and endkey parameters" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"firstname" => 'Carl', 'lastname' => 'Alf', 'ruby_class' => 'User'}
          @db['user_3'] = {"firstname" => 'Alf', 'lastname' => 'Horst', 'ruby_class' => 'User'}
          
          assert_equal(JSON.parse({
            "total_rows" => 2,
            "offset" => 0,
            "rows" => [{
              "id" => "user_1",
              "endkey" => "Alf",
              "value" => nil,
              "startkey" => "Alf",
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Bert",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_1' }
              }, {
              "id" => "user_3",
              "endkey" => "Alf",
              "value" => nil,
              "startkey" => "Alf",
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Horst",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_3' }
              }
            ]}.to_json), JSON.parse(@db.view('user', 'by_firstname', 'startkey' => "Alf".to_json, 'endkey' => "Alf".to_json, 'include_docs' => 'true')))
        end
        
        should "support startkey/endkey combined with startkey_docid/endkey_docid parameters" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"firstname" => 'Carl', 'lastname' => 'Alf', 'ruby_class' => 'User'}
          @db['user_3'] = {"firstname" => 'Alf', 'lastname' => 'Horst', 'ruby_class' => 'User'}
          
          assert_equal(JSON.parse({
            "total_rows" => 2,
            "offset" => 0,
            "rows" => [{
              "id" => "user_3",
              "startkey" => "Alf",
              "endkey" => "Alf",
              "startkey_docid" => "user_3",
              "endkey_docid" => "user_3",
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Horst",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_3' }
              }
            ]}.to_json), JSON.parse(@db.view('user', 'by_firstname', 'startkey' => "Alf".to_json, 'endkey' => "Alf".to_json, 'startkey_docid' => "user_3".to_json, "endkey_docid" => 'user_3'.to_json, 'include_docs' => 'true', 'limit' => '1')))
        end
      end
      
      context "belongs_to" do
        should "load parent" do
          @db['project_1'] = {"title" => 'alpha', 'ruby_class' => 'Project'}
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'project_id' => 'project_1', 'ruby_class' => 'User'}
                  
          assert_equal({
            "total_rows" => 1,
            "offset" => 0,
            "rows" => [{
              "id" => "user_1",
              "key" => "project_1",
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Bert",
                "project_id" => "project_1",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_1' }
              }
            ]}.to_json, @db.view('user', 'association_user_belongs_to_project', 'key' => "project_1".to_json, 'include_docs' => 'true'))
        end
      end
      
      context "all_documents" do
        should "load all documents of the matching class" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"firstname" => 'Carl', 'lastname' => 'Alf', 'ruby_class' => 'User'}
          @db['project_1'] = {"title" => 'Alpha', 'ruby_class' => 'Project'}
          
          assert_equal({
            "total_rows" => 2,
            "offset" => 0,
            "rows" => [{
              "id" => "user_1",
              "key" => nil,
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Bert",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_1' }
              }, {
              "id" => "user_2",
              "key" => nil,
              "value" => nil,
              "doc" => {
                "firstname" => "Carl",
                "lastname" => "Alf",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_2' }
              }
            ]}.to_json, @db.view('user', 'all_documents', 'include_docs' => 'true'))
        end
        
        should "limit the results if asked to" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"firstname" => 'Carl', 'lastname' => 'Alf', 'ruby_class' => 'User'}
          
          assert_equal({
            "total_rows" => 2,
            "offset" => 0,
            "rows" => [{
              "id" => "user_1",
              "key" => nil,
              "value" => nil,
              "doc" => {
                "firstname" => "Alf",
                "lastname" => "Bert",
                'ruby_class' => 'User',
                '_rev' => 'the-rev',
                '_id' => 'user_1' }
              }
            ]}.to_json, @db.view('user', 'all_documents', 'include_docs' => 'true', 'limit' => '1'))
        end
        
        should "count the objects with reduce" do
          @db['user_1'] = {"firstname" => 'Alf', 'lastname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"firstname" => 'Carl', 'lastname' => 'Alf', 'ruby_class' => 'User'}
          
          assert_equal({
            "rows" => [{ "key" => nil, "value" => 2}]
          }.to_json, @db.view('user', 'all_documents', 'include_docs' => 'false', 'reduce' => 'true'))
        end
      end
      
      context "has and belongs to many views" do
        setup do
          @db['group_1'] = {"name" => 'A', 'ruby_class' => 'Group'}
          @db['group_2'] = {"name" => 'B', 'ruby_class' => 'Group'}
          @db['user_1'] = {"group_ids" => ['group_1', 'group_2'], 'firstname' => 'Bert', 'ruby_class' => 'User'}
          @db['user_2'] = {"group_ids" => ['group_1'], 'firstname' => 'Alf', 'ruby_class' => 'User'}
          @db['_design/group'] = { 'language' => 'javascript', 'views' => {
            'all_documents' => {
              'reduce' => nil,
              'map' => "function(item){emit(item)}"
            },
            'association_group_has_and_belongs_to_many_users' => {
              'reduce' => "function(key, values){ return values.length }",
              "map" => "function(doc) {\n if(doc.ruby_class && doc.ruby_class == 'Instance') {\n emit(doc['created_at'], null);\n }\n }"
            }
          }}
        end

        should "return all item not storing keys" do
          assert_equal(JSON.parse({
            "total_rows" => 2,
            "rows" => [
              {"doc" => {
                  "_rev" => "the-rev",
                  "group_ids" => ["group_1","group_2"],
                  "_id" => "user_1",
                  "firstname" => "Bert",
                  "ruby_class" => "User"
                },
                "id" => "user_1",
                "value" => nil,
                "key" => "group_1"
              },{
                "doc" => {
                  "_rev" => "the-rev",
                  "group_ids" => ["group_1"],
                  "_id" => "user_2",
                  "firstname" => "Alf",
                  "ruby_class" => "User"
                },
                "id" => "user_2",
                "value" => nil,
                "key" => "group_1"
              }],
              "offset" => 0}.to_json), JSON.parse(@db.view('user', 'association_user_has_and_belongs_to_many_groups', 'key' => "group_1".to_json, 'include_docs' => 'true')))
        end

        should "return all item storing keys" do
          assert_equal(JSON.parse({
            "total_rows" => 2,
            "rows" => [
              {"doc" => {
                  "_rev" => "the-rev",
                  "_id" => "group_1",
                  "name" => "A",
                  "ruby_class" => "Group"
                },
                "id" => "group_1",
                "value" => nil,
                "key" => "user_1"
              },{
                "doc" => {
                  "_rev" => "the-rev",
                  "_id" => "group_2",
                  "name" => "B",
                  "ruby_class" => "Group"
                },
                "id" => "group_2",
                "value" => nil,
                "key" => "user_1"
              }],
              "offset" => 0}.to_json), JSON.parse(@db.view('group', 'association_group_has_and_belongs_to_many_users', 'key' => "user_1".to_json, 'include_docs' => 'true')))
        end
      end
    end
    
  end
end