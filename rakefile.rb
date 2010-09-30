#!usr/bin/ruby

require 'bundler/setup'
require 'active_record'
require 'logger'
require 'rake/testtask'
require 'yaml'
# TODO: why doesn't the rcov task run?
#require 'rcov/rcovtask'

task :default => :test

namespace :db do
  desc "Set up the connection to the database"
  task :environment do
    dbconfig = YAML.load(File.read('config/database.yml'))

    # in frank.rb we configure for test, development and production only right now.
    # and no matter what you sepcify, the tests are always run against the test database
    # so be sure to seed all the databases before running this
    # %> RACK_ENV=test rake db:seed
    # %> RACK_ENV=development rake db:seed
    # %> RACK_ENV=production rake db:seed
    # Note also that, when pushed to Heroku, the databases will switch to PostGRES
    ActiveRecord::Base.establish_connection dbconfig[ENV['RACK_ENV']||'development']
  end

  desc "Migrate the database by walking through the migrations in db/migrate"
  task(:migrate => :environment) do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Migrator.migrate("db/migrate", ENV["VERSION"] ? ENV[VERSION].to_i : nil)
  end
  
  desc 'Load the seed data from db/seeds.rb'
  task(:seed => :migrate) do
    seed_file = File.join('db', "#{ENV['RACK_ENV']}_seeds.rb")
    if File.exists?(seed_file)
      load(seed_file)
    else
      seed_file = File.join('db', 'seeds.rb')
      if File.exists?(seed_file)
        load(seed_file)
      else
        puts "WARNING -- NO DATABASE SEED DATA FOUND."
      end
    end
  end
end

desc "run the tests"
task(:test => 'db:environment') do
  puts "Tests running in environment '#{ENV['RACK_ENV']}'"
  Rake::TestTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/*_test.rb']
    t.verbose = false
  end
end

# note for some reason this task does not run but you can do this anyway by
# % rcov test/*_test.rb --exclude /gems/,/Library/,/usr/
# from the command line.
#desc "Run the rcov profiler to generate test coverage reports."
#task(:coverage => 'db:environment') do
#  Rcov::RcovTask.new do |t|
#    t.libs << "test"
#    t.test_files = FileList['test/*_test.rb']
#    t.exclude = ['/gems/','/Library/','/usr/']
#    t.output_dir = "coverage"
#    t.verbose = true
#  end
#end
