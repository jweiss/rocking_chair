# encoding: utf-8

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, :test)

$:.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require "rocking_chair"

require 'test/unit'
require 'shoulda'
require 'mocha'
require 'json/ext'
require 'active_support/inflector'
require 'couchrest_extended_document'

require File.expand_path(File.dirname(__FILE__) + "/fixtures/extended_couch_rest_fixtures")
require File.expand_path(File.dirname(__FILE__) + "/fixtures/simply_stored_fixtures")

RockingChair.enable

def assert_error_code(code, &blk)
  ex = nil
  begin
    blk.call
  rescue Exception => e
    ex = e
  ensure
    assert_not_nil ex, "No Exception raised!"
    assert_equal RockingChair::Error, ex.class, "The raised exception is not a RockingChair::Error: #{e.class}: #{e.message} - #{e.backtrace.join("\n")}"
    assert_equal code, ex.code
  end
end

def dump_RockingChair
  puts "No datases set yet!" if RockingChair::Server.databases.empty?
  RockingChair::Server.databases.each do |db_name, db|
    puts "Content of Database #{db_name}: \n\n#{db.inspect}"
  end
end

def with_debug(&blk)
  HttpAbstraction.instance_variable_set("@_rocking_chair_debug", true)
  blk.call
  HttpAbstraction.instance_variable_set("@_rocking_chair_debug", false)
end

def parse_json(string)
  JSON.parse(string, :create_additions => false)
end