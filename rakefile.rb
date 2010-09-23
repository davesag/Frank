#!usr/bin/ruby

require 'active_record'
require 'logger'
require 'rake/testtask'

task :default => :test

namespace :db do
  desc "Set up the connection to the database"
  task :environment do
    ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database =>  '.FrankData.sqlite3.db'
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
    t.verbose = true
  end
end
