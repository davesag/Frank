#!usr/bin/ruby

require 'active_record'
require 'models/user'

user = User.find_by_username("root")
if user == nil
  User.create!(:username => "root", :password => "password", :email => "Frank_root_user@davesag.com")
end

