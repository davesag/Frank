#!usr/bin/ruby

require 'active_record'
require 'models/user'
require 'models/preference'
require 'models/role'

role = Role.find_by_name("admin")
if role == nil
  puts "Seeding database - adding admin role"
  role = Role.create( :name => "admin")
end

puts "Seeding database with Root User"

user = User.find_by_username("root")
if user != nil
  puts "Overwriting old Root User"
  user.destroy
end
user = User.create( :username => "root", :password => "password", :email => "Frank_root_user@davesag.com")
user.set_preference("HTML_EMAIL", "false")
puts "adding admin role..."
user.add_role("admin")
user.validated = true
user.save!
puts "Root User saved"

puts "Seeding database with user nobody"
user = User.find_by_username("nobody")
if user != nil
  puts "Overwriting old user nobody"
  user.destroy
end
user = User.create( :username => "nobody", :password => "password", :email => "Frank_nobody_user@davesag.com")
user.set_preference("HTML_EMAIL", "false")
user.validated = true
user.save!
puts "User nobody saved"
