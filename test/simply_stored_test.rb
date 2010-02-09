require File.dirname(__FILE__) + "/test_helper"

def recreate_db
  CouchPotato.couchrest_database.delete! rescue nil
  CouchPotato.couchrest_database.server.create_db CouchPotato::Config.database_name
end

class SimplyStoredTest < Test::Unit::TestCase
  context "Extended use cases for SimplyStored" do
    setup do
      Fakecouch::Server.reset
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
          Fakecouch::Server.reset
          CouchPotato::Config.database_name = 'fake_simply_stored'
          recreate_db
        end
        
        should "load all has_many objects" do
          user = User.new(:firstname => 'Michael', :project => @project)
          assert user.save
          assert_equal [user.id], @project.users.map(&:id)
        end
      end
      
      context "when querying the all_documents view" do
        setup do
          Fakecouch::Server.reset
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
        
        context "with deleted" do
          should "ignore deleted in find all"
          should "ignore deleted in find first"
          should "ignore deleted in belongs to"
          should "ignore deleted in has_one"
          should "ignore deleted in has_many"
        end
      end
      
      
    end
     
  end
end