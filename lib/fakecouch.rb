require "rubygems"
require "active_support"
require "uuidtools"
require "cgi"
require "couchrest"


require "fakecouch/error"
require "fakecouch/database"
require "fakecouch/server"
require "fakecouch/couch_rest_http_adapter"

module Fakecouch
  
  def self.enable
    HttpAbstraction.extend(Fakecouch::CouchRestHttpAdapter)
  end
  
  def self.disable
    HttpAbstraction.extend(RestClientAdapter::API)
  end
  
end