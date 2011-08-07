# encoding: utf-8

require 'simply_stored/couch'

class User
  include SimplyStored::Couch

  property :firstname
  property :lastname
  belongs_to :project
  has_and_belongs_to_many :groups, :storing_keys => true
  
  enable_soft_delete
  
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

class CustomFiewUser
  include SimplyStored::Couch
  
  property :tags
  view :by_tags, :type => SimplyStored::Couch::Views::ArrayPropertyViewSpec, :key => :tags
end

class Group
  include SimplyStored::Couch

  property :name
  has_and_belongs_to_many :users, :storing_keys => false
end

class Server
  include SimplyStored::Couch

  property :hostname

  has_and_belongs_to_many :networks, :storing_keys => true
end

class Network
  include SimplyStored::Couch

  property :klass

  has_and_belongs_to_many :servers, :storing_keys => false
end