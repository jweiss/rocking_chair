# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + "/test_helper")

def recreate_db
  CouchPotato.couchrest_database.delete! rescue nil
  CouchPotato.couchrest_database.server.create_db CouchPotato::Config.database_name
end

class SimplyStoredTest < Test::Unit::TestCase
  [false, true].each do |setting|
    CouchPotato::Config.split_design_documents_per_view = setting
    
    context "Extended use cases for SimplyStored with split_design_documents_per_view #{setting ? 'enabled' : 'disabled'}" do
      setup do
        RockingChair::Server.reset
        CouchPotato::Config.database_name = 'fake_simply_stored'
        recreate_db
      end
    
      context "storing and loading documents" do
        should "save and find Projects" do
          p = Project.new(:title => 'The title')
          assert p.save
          assert_not_nil p.id, p.inspect
          project = Project.find(p.id)
          assert_equal 'The title', project.title
        end
      
        should "save and find Users" do
          p = Project.new(:title => 'The title')
          assert p.save
          u = User.new(:firstname => 'Doc', :lastname => 'Holiday', :project => p)
          assert u.save
          user = User.find(u.id)
          assert_equal 'Doc', user.firstname
          assert_equal 'Holiday', user.lastname
          assert_equal p.id, user.project_id
          assert_equal p, user.project
        end
      end
    
      context "Views" do
        setup do
          @manager = Manager.new(:firstname => 'Michael')
          assert @manager.save
        
          @project = Project.new(:title => 'The title', :manager => @manager)
          assert @project.save
        
          @user = User.new(:firstname => 'Michael', :project => @project)
          assert @user.save
        end
      
        context "by_attribute views" do
      
          should "load first" do
            user_1 = User.create(:firstname => 'Bart', :lastname => 'S')
            user_2 = User.create(:firstname => 'Homer', :lastname => 'J')
            assert_equal 'J', User.find_by_firstname('Homer').lastname
          end
      
          should "load all" do
            user_1 = User.create(:firstname => 'Bart', :lastname => 'S')
            user_2 = User.create(:firstname => 'Homer', :lastname => 'J')
            user_2 = User.create(:firstname => 'Homer', :lastname => 'S')
            assert_equal ['S', 'J'].sort, User.find_all_by_firstname('Homer').map(&:lastname).sort
          end
      
          should "only load objects from the correct class" do
            user = User.create(:firstname => 'Bart', :lastname => 'S')
            manager = Manager.create(:firstname => 'Bart', :lastname => 'J')
            assert_equal ['S'], User.find_all_by_firstname('Bart').map(&:lastname)
          end
        
          should "support multiple attributes" do
            user_1 = User.create(:firstname => 'Bart', :lastname => 'S')
            user_2 = User.create(:firstname => 'Homer', :lastname => 'J')
            user_2 = User.create(:firstname => 'Homer', :lastname => 'S')
            assert_equal ['J'].sort, User.find_all_by_firstname_and_lastname('Homer', 'J').map(&:lastname).sort
          end
        end
      
        context "belongs_to" do
          should "load the parent object" do
            assert_equal @project.id, @user.project.id
          end
        end
      
        context "has_one" do
          should "load the child object" do
            assert_equal @project.id, @manager.project.id
            assert_equal @manager.id, @project.manager.id
          end
        
          should "re-use existing views" do
            Manager.create(:firstname => 'Jochen', :lastname => 'Peter')
            Manager.create(:firstname => 'Another', :lastname => 'Bert')
          end
        end
      
        context "has_many" do
          setup do
            RockingChair::Server.reset
            CouchPotato::Config.database_name = 'fake_simply_stored'
            recreate_db
          end
        
          should "load all has_many objects" do
            user = User.new(:firstname => 'Michael', :project => @project)
            assert user.save
            assert_equal [user.id], @project.users.map(&:id)
          end
        
          should "support counting associated" do
            assert_equal 0, @project.user_count
            user = User.create(:firstname => 'Michael', :project => @project)
            assert_equal 1, @project.user_count(:force_reload => true)
          end
        
          should "support limiting" do
            3.times{ User.create!(:firstname => 'Michael', :project => @project) }
            assert_equal 3, @project.users.size
            assert_equal 2, @project.users(:limit => 2).size
          end
                
          should "support mixing order and limit" do
            michael = User.find(User.create!(:firstname => "michael", :project => @project).id)
            michael.created_at = Time.local(2001)
            michael.save!
          
            mickey = User.find(User.create!(:firstname => "mickey", :project => @project).id)
            mickey.created_at = Time.local(2002)
            mickey.save!
          
            mike = User.find(User.create!(:firstname => "mike", :project => @project).id)
            mike.created_at = Time.local(2003)
            mike.save!
          
            assert_equal ["michael", "mickey", "mike"], @project.users(:order => :asc).map(&:firstname)
            assert_equal ["michael", "mickey", "mike"].reverse, @project.users(:order => :desc).map(&:firstname)
          end
        end
      
        context "when querying the all_documents view" do
          setup do
            RockingChair::Server.reset
            CouchPotato::Config.database_name = 'fake_simply_stored'
            recreate_db
          end
        
          should "load all from the same class" do
            User.create(:firstname => 'Michael Mann', :project => @project)
            User.create(:firstname => 'Peter', :project => @project)
            assert_equal ['Peter', 'Michael Mann'].sort, User.all.map(&:firstname).sort
          
            User.create(:firstname => 'Hulk', :project => @project)
            assert_equal ['Peter', 'Michael Mann', 'Hulk'].sort, User.all.map(&:firstname).sort
          end
        
          should "support order" do
            3.times{|i| User.create!(:firstname => "user #{i}") }
            assert_not_equal User.all(:order => :asc).map(&:id), User.all(:order => :desc).map(&:id)
            assert_equal User.all(:order => :asc).reverse, User.all(:order => :desc)
          end
        
          should "load first" do
            User.create(:firstname => 'Michael Mann', :project => @project)
            User.create(:firstname => 'Peter', :project => @project)
            assert User.first.respond_to?(:firstname)
          end
        
          should "count" do
            User.create(:firstname => 'Michael the first')
        
            assert_equal 0, Project.count
            assert_equal 0, Manager.count
            assert_equal 1, User.count

            Manager.create(:firstname => 'Jochen', :lastname => 'Peter')
            Project.create(:title => 'The title', :manager => @manager)
            Project.create(:title => 'another title', :manager => @manager)
            User.create(:firstname => 'Michael Mann', :project => @project)
            User.create(:firstname => 'Peter', :project => @project)

            assert_equal 2, Project.count
            assert_equal 1, Manager.count
            assert_equal 3, User.count
          end
        
          should "count_by" do
            User.create(:firstname => 'michael')
        
            assert_equal 1, User.count
            assert_equal 1, User.count_by_firstname('michael')
          end
        
          should "count_by with nil attributes" do
            p = Project.create(:title => nil)
        
            assert_equal 1, Project.count
            assert_equal 1, Project.count_by_title(nil)
            assert_equal p, Project.find_by_title(nil)
          
            Project.create(:title => nil, :manager_id => 12)
          
            assert_equal 2, Project.count
            assert_equal 2, Project.count_by_title(nil)
            assert_equal 1, Project.count_by_manager_id(12)
            assert_equal 1, Project.count_by_manager_id_and_title(12, nil)
          
            Project.create(:title => 'Hi There')
          
            assert_equal 3, Project.count
            assert_equal 2, Project.count_by_title(nil)
          end
        
          context "with deleted" do
            setup do
              RockingChair::Server.reset
              CouchPotato::Config.database_name = 'fake_simply_stored'
              recreate_db
            end
          
            should "ignore deleted in find all but load them in all with deleted" do
              user = User.new(:firstname => 'Bart', :lastname => 'S')
              assert user.save
            
              deleted_user = User.new(:firstname => 'Pete', :lastname => 'S')
              assert deleted_user.save
            
              deleted_user.destroy

              assert_equal ['Bart'], User.all.map(&:firstname)
              assert_equal ['Bart', 'Pete'].sort, User.find(:all, :with_deleted => true).map(&:firstname).sort
            end
          
            should "ignore deleted in find first" do
              user = User.new(:firstname => 'Bart', :lastname => 'S')
              assert user.save
              assert_equal 'Bart', User.find(:first).firstname
              user.destroy
              assert_nil User.first
              assert_equal 'Bart', User.find(:first, :with_deleted => true).firstname
            end
          
            should "ignore deleted in belongs_to/has_many" do
              project = Project.new(:title => 'secret')
              assert project.save
            
              user = User.new(:firstname => 'Bart', :lastname => 'S', :project => project)
              assert user.save
            
              assert_equal [user.id], project.users.map(&:id)
              user.destroy
            
              assert_equal [], project.users(:force_reload => true, :with_deleted => false).map(&:id)
              assert_equal [user.id], project.users(:force_reload => true, :with_deleted => true).map(&:id)
            end
          
          end
        end
      
        context "With array views" do

          should "find objects with one match of the array" do
            CustomFiewUser.create(:tags => ["agile", "cool", "extreme"])
            CustomFiewUser.create(:tags => ["agile"])
            assert_equal 2, CustomFiewUser.find_all_by_tags("agile").size
          end

          should "find the object when the property is not an array" do
            CustomFiewUser.create(:tags => "agile")
            assert_equal 1, CustomFiewUser.find_all_by_tags("agile").size
          end
        end
      
      end
    
      context "when deleting" do
        should "delete the doc" do
          user = User.new(:firstname => 'Bart', :lastname => 'S')
          assert user.save
          assert user.delete
        end
      end
    
      context "when handling n:m relations using has_and_belongs_to_many" do
        should "work relations from both sides" do
          network_a = Network.create(:klass => "A")
          network_b = Network.create(:klass => "B")
          3.times {
            server = Server.new
            server.add_network(network_a)
            server.add_network(network_b)
          }
          assert_equal 3, network_a.servers.size
          network_a.servers.each do |server|
            assert_equal 2, server.networks.size
          end
          assert_equal 3, network_b.servers.size
          network_b.servers.each do |server|
            assert_equal 2, server.networks.size
          end
        end

        should "work relations from both sides - regardless from where the add was called" do
          network_a = Network.create(:klass => "A")
          network_b = Network.create(:klass => "B")
          3.times {
            server = Server.new
            network_a.add_server(server)
            network_b.add_server(server)
          }
          assert_equal 3, network_a.servers.size
          network_a.servers.each do |server|
            assert_equal 2, server.networks.size, server.network_ids.inspect
          end
          assert_equal 3, network_b.servers.size
          network_b.servers.each do |server|
            assert_equal 2, server.networks.size
          end
        end

        should "cound correctly - regardless of the side of the relation" do
          network_a = Network.create(:klass => "A")
          network_b = Network.create(:klass => "B")
          3.times {
            server = Server.new
            network_a.add_server(server)
            network_b.add_server(server)
          }
          assert_equal 3, network_a.server_count
          assert_equal 3, network_b.server_count
          assert_equal 2, network_a.servers.first.network_count
          assert_equal 2, network_b.servers.first.network_count
        end

        should "support mixing order and limit" do
          network_1 = Network.find(Network.create!(:klass => "A").id)
          network_1.created_at = Time.local(2001)
          network_1.save!

          network_2 = Network.find(Network.create!(:klass => "B").id)
          network_2.created_at = Time.local(2002)
          network_2.save!

          server_1 = Server.find(Server.create!(:hostname => 'www.example.com').id)
          server_1.created_at = Time.local(2003)
          network_1.add_server(server_1)
          network_2.add_server(server_1)

          server_2 = Server.find(Server.create!(:hostname => 'foo.com').id)
          server_2.created_at = Time.local(2004)
          network_1.add_server(server_2)
          network_2.add_server(server_2)

          assert_equal ['www.example.com', 'foo.com'], network_1.servers(:order => :asc).map(&:hostname)
          assert_equal ['www.example.com', 'foo.com'].reverse, network_1.servers(:order => :desc).map(&:hostname)

          assert_equal ['A', 'B'], server_2.networks(:order => :asc).map(&:klass)
          assert_equal ['A', 'B'].reverse, server_2.networks(:order => :desc).map(&:klass)

          assert_equal ['www.example.com'], network_1.servers(:order => :asc, :limit => 1).map(&:hostname)
          assert_equal ['foo.com'], network_1.servers(:order => :desc, :limit => 1).map(&:hostname)

          assert_equal ['A'], server_2.networks(:order => :asc, :limit => 1).map(&:klass)
          assert_equal ['B'], server_2.networks(:order => :desc, :limit => 1).map(&:klass)
        end
      
        should "when counting cache the result" do
          @network = Network.create(:klass => "C")
          @server = Server.create
          assert_equal 0, @network.server_count
          Server.create(:network_ids => [@network.id])
          assert_equal 0, @network.server_count
          assert_equal 0, @network.instance_variable_get("@server_count")
          @network.instance_variable_set("@server_count", nil)
          assert_equal 1, @network.server_count
        end

        should "when counting cache the result - from both directions" do
          @network = Network.create(:klass => "C")
          @server = Server.create
          assert_equal 0, @server.network_count
          @server.network_ids = [@network.id]
          @server.save!
          assert_equal 0, @server.network_count
          assert_equal 0, @server.instance_variable_get("@network_count")
          @server.instance_variable_set("@network_count", nil)
          assert_equal 1, @server.network_count
        end
      end

      context "when deleting all design docs" do
        should "reset all design docs" do
          User.find_all_by_firstname('a')
          db = "http://127.0.0.1:5984/#{CouchPotato::Config.database_name}"
          assert_nothing_raised do
            assert_equal 1, SimplyStored::Couch.delete_all_design_documents(db)
          end
        end
      end
    end
  end
end