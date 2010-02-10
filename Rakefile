require 'rake'
require 'rake/testtask'

task :default => [:test]

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = "test/**/*_test.rb"
  t.verbose = true
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "rocking_chair"
    s.summary = %Q{In-memory CouchDB for Couchrest and SimplyStored}
    s.email = "jw@innerewut.de"
    s.homepage = "http://github.com/jweiss/rocking_chair"
    s.description = "In-memory CouchDB for Couchrest and SimplyStored. Works for database and document API, by_attribute views, and for SimplyStored generated views"
    s.authors = ["Jonathan Weiss"]
    s.files = FileList["[A-Z]*.*", "{lib}/**/*"]
    s.add_dependency('simply_stored', '>= 0.1.12')
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end