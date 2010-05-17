require File.dirname(__FILE__) + "/test_helper"

def recreate_db
  CouchPotato.couchrest_database.delete! rescue nil
  CouchPotato.couchrest_database.server.create_db CouchPotato::Config.database_name
end

class SimplyStoredTest < Test::Unit::TestCase
  context "Extended use cases for SimplyStored" do
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
          Project.create(:title => nil)
        
          assert_equal 1, Project.count
          assert_equal 1, Project.count_by_title(nil)
          
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
          CustomViewUser.create(:tags => ["agile", "cool", "extreme"])
          CustomViewUser.create(:tags => ["agile"])
          assert_equal 2, CustomViewUser.find_all_by_tags("agile").size
        end

        should "find the object when the property is not an array" do
          CustomViewUser.create(:tags => "agile")
          assert_equal 1, CustomViewUser.find_all_by_tags("agile").size
        end
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