require File.dirname(__FILE__) + "/test_helper"

class ExtendedCouchRestTest < Test::Unit::TestCase
  context "Extended use cases for CouchRest" do
    setup do
      RockingChair::Server.reset
      SERVER.create_db('couchrest-extendeddoc-example')
    end
    
    context "CouchRest::ExtendedDocument" do
      should "save and load Posts" do
        p = Post.new(:title => 'The title', :body => 'The body')
        assert p.save
        post = Post.get(p.id)
        assert_equal 'The title', post.title
        assert_equal 'The body', post.body
      end
      
      should "save and load Comments" do
        post = Post.new(:title => 'The title', :body => 'The body')
        assert post.save
        c = Comment.new(:body => 'The body of the comment', :post_id => post.id)
        assert c.save
        comment = Comment.get(c.id)
        assert_equal 'The body of the comment', comment.body
        assert_equal post.id, comment.post_id
      end
    end
    
    context "Views" do
      
      setup do
        @post = Post.new(:title => 'The title', :body => 'The body')
        assert @post.save
      end

      # should "support simple by-attribute views" do
      #   comment = Comment.new(:body => 'The body of the comment', :post_id => @post.id)
      #   assert comment.save
      #   lonely_comment = comment = Comment.new(:body => 'The body of the comment', :post_id => nil)
      #   assert lonely_comment.save
      #   
      #   assert_equal [comment.id], Comment.by_post_id(:key => @post.id).map(&:id)
      # end

    end
     
  end
end