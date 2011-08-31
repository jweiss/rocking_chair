# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "rocking_chair"
  s.version = "0.4.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jonathan Weiss"]
  s.date = "2011-08-31"
  s.description = "In-memory CouchDB for Couchrest and SimplyStored. Works for database and document API, by_attribute views, and for SimplyStored generated views"
  s.email = "jw@innerewut.de"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    "Gemfile.lock",
    "LICENSE.txt",
    "README.md",
    "lib/rocking_chair.rb",
    "lib/rocking_chair/couch_rest_http_adapter.rb",
    "lib/rocking_chair/database.rb",
    "lib/rocking_chair/error.rb",
    "lib/rocking_chair/helper.rb",
    "lib/rocking_chair/http_adapter.rb",
    "lib/rocking_chair/server.rb",
    "lib/rocking_chair/view.rb"
  ]
  s.homepage = "http://github.com/jweiss/rocking_chair"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.10"
  s.summary = "In-memory CouchDB for Couchrest and SimplyStored"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<uuidtools>, [">= 0"])
      s.add_runtime_dependency(%q<simply_stored>, ["= 0.7.0rc2"])
      s.add_runtime_dependency(%q<couch_potato>, ["= 0.5.7.3"])
      s.add_runtime_dependency(%q<jeweler>, [">= 0"])
      s.add_runtime_dependency(%q<simply_stored>, [">= 0.1.12"])
      s.add_runtime_dependency(%q<rest-client>, [">= 1.6.1"])
      s.add_runtime_dependency(%q<couchrest>, [">= 1.0.1"])
    else
      s.add_dependency(%q<uuidtools>, [">= 0"])
      s.add_dependency(%q<simply_stored>, ["= 0.7.0rc2"])
      s.add_dependency(%q<couch_potato>, ["= 0.5.7.3"])
      s.add_dependency(%q<jeweler>, [">= 0"])
      s.add_dependency(%q<simply_stored>, [">= 0.1.12"])
      s.add_dependency(%q<rest-client>, [">= 1.6.1"])
      s.add_dependency(%q<couchrest>, [">= 1.0.1"])
    end
  else
    s.add_dependency(%q<uuidtools>, [">= 0"])
    s.add_dependency(%q<simply_stored>, ["= 0.7.0rc2"])
    s.add_dependency(%q<couch_potato>, ["= 0.5.7.3"])
    s.add_dependency(%q<jeweler>, [">= 0"])
    s.add_dependency(%q<simply_stored>, [">= 0.1.12"])
    s.add_dependency(%q<rest-client>, [">= 1.6.1"])
    s.add_dependency(%q<couchrest>, [">= 1.0.1"])
  end
end

