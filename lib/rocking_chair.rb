require "rubygems"
require "active_support/core_ext/hash"
require "uuidtools"
require "cgi"
require "couchrest"


require "rocking_chair/helper"
require "rocking_chair/error"
require "rocking_chair/view"
require "rocking_chair/database"
require "rocking_chair/server"
require "rocking_chair/couch_rest_http_adapter"

module RockingChair
  
  @_rocking_chair_enabled
  
  def self.enable
    unless @_rocking_chair_enabled
      HttpAbstraction.extend(RockingChair::CouchRestHttpAdapter)
      @_rocking_chair_enabled = true
    end
  end
  
  def self.disable
    if @_rocking_chair_enabled
      HttpAbstraction.extend(RestClientAdapter::API)
      @_rocking_chair_enabled = false
    end
  end
  
end