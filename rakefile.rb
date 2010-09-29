#!usr/bin/ruby

require 'active_record'
require 'logger'
require 'rake/testtask'
require 'rcov/rcovtask'

task :default => :test

namespace :db do
  desc "Set up the connection to the database"
  task :environment do
    ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database =>  'Frank_Test_data.db'
  end

  desc "Migrate the database by walking through the migrations in db/migrate"
  task(:migrate => :environment) do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Migrator.migrate("db/migrate", ENV["VERSION"] ? ENV[VERSION].to_i : nil)
  end
  
  desc 'Load the seed data from db/seeds.rb'
  task(:seed => :migrate) do
    seed_file = File.join('db', 'seeds.rb')
    load(seed_file) if File.exist?(seed_file)
  end
end

desc "run the tests"
task(:test => 'db:environment') do
  Rake::TestTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/*_test.rb']
    t.verbose = false
  end
end

# note for some reason this task does not run but you can do this anyway by
# % rcov test/*_test.rb
# from the command line.
desc "Run the rcov profiler to generate test coverage reports."
task(:coverage => 'db:environment') do
  Rcov::RcovTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/*_test.rb']
    t.output_dir = "coverage"
    t.verbose = true
  end
end
