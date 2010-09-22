#!usr/bin/ruby

require 'active_record'
require 'models/user'
require 'models/preference'

puts "Seeding database with Root User"

user = User.find_by_username("root")
if user != nil
  puts "Overwriting old Root User"
  user.destroy
end
user = User.create( :username => "root", :password => "password", :email => "Frank_root_user@davesag.com")
user.set_preference("HTML_EMAIL", "false")
user.validated = true
user.save!
puts "Root User saved"
