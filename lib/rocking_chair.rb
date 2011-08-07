# encoding: utf-8

require "rubygems"
require 'active_support/core_ext/kernel/reporting'
require "active_support/core_ext/hash"
require "active_support/core_ext/module"
require 'active_support/deprecation'
require "active_support/core_ext/object/blank"
require 'active_support/json'
require "uuidtools"
require "cgi"
require "couchrest"


require "rocking_chair/helper"
require "rocking_chair/error"
require "rocking_chair/view"
require "rocking_chair/database"
require "rocking_chair/server"
require "rocking_chair/couch_rest_http_adapter"
require "rocking_chair/http_adapter"


module RockingChair

  @_rocking_chair_enabled = false
  
  def self.enable
    @_rocking_chair_enabled = true
  end
  
  def self.disable
    @_rocking_chair_enabled = false
  end
  
  def self.enabled?
    @_rocking_chair_enabled
  end
  
  def self.enable_debug
    RockingChair::CouchRestHttpAdapter.instance_variable_set("@_rocking_chair_debug", true)
  end
  
  def self.disable_debug
    RockingChair::CouchRestHttpAdapter.instance_variable_set("@_rocking_chair_debug", false)
  end
  
end