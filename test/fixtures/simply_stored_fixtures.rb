require 'simply_stored/couch'

class User
  include SimplyStored::Couch

  property :firstname
  property :lastname
  belongs_to :project
  
  view :by_name, :key => :name
end

class Project
  include SimplyStored::Couch

  property :title
  has_many :users
  belongs_to :manager
end

class Manager
  include SimplyStored::Couch

  property :firstname
  property :lastname
  has_one :project
end