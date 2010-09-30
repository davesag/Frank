#!usr/bin/ruby

require 'active_record'
require 'models/user'
require 'models/preference'
require 'models/role'

roles = ["admin", "superuser", "user"]
roles.each do |rolename|
  role = Role.find_by_name(rolename)
  if role == nil
    role = Role.create( :name => rolename)
  end
end

user = User.find_by_username("root")
if user != nil
  puts "Overwriting old Root User"
  user.destroy
end
user = User.create( :username => "root", :password => "password", :email => "Frank_root_user@davesag.com")
user.set_preference("HTML_EMAIL", "false")
user.add_role("superuser")
user.add_role("admin")
user.locale = 'en'
user.validated = true
user.save!
