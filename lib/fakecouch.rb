require "rubygems"
require "active_support"
require "uuidtools"
require "cgi"
require "couchrest"


require "fakecouch/helper"
require "fakecouch/error"
require "fakecouch/view"
require "fakecouch/database"
require "fakecouch/server"
require "fakecouch/couch_rest_http_adapter"

module Fakecouch
  
  @_fake_couch_enabled
  
  def self.enable
    unless @_fake_couch_enabled
      HttpAbstraction.extend(Fakecouch::CouchRestHttpAdapter)
      @_fake_couch_enabled = true
    end
  end
  
  def self.disable
    if @_fake_couch_enabled
      HttpAbstraction.extend(RestClientAdapter::API)
      @_fake_couch_enabled = false
    end
  end
  
end