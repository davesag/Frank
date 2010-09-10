#!usr/bin/ruby

require 'active_record'
require 'models/user'
require 'models/preference'

user = User.find_by_username("root")
if user != nil
  user.destroy
end
user = User.create(:username => "root", :password => "password", :email => "Frank_root_user@davesag.com")
user.set_preference("HTML_EMAIL", "false")
user.save!
