SERVER = CouchRest.new
SERVER.default_database = 'couchrest-extendeddoc-example'

class Comment < CouchRest::ExtendedDocument
  use_database SERVER.default_database
  property :body
  property :post_id
  timestamps!  
  
  view_by :post_id
end

class Post < CouchRest::ExtendedDocument
  use_database SERVER.default_database  
  property :title
  property :body
  timestamps!
  
  def comments
    Comment.by_post_id :key => id
  end
end

