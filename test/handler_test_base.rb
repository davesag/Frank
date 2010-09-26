#!usr/bin/ruby

ENV['RACK_ENV'] = 'test'

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'

class HandlerTestBase < Test::Unit::TestCase
  include Rack::Test::Methods

# pull the app definition from the Rack config file.
  def app
    @app ||= Rack::Builder.parse_file(File.join(Frank.root,"config.ru"))[0]
  end

# see db/seeds.rb for the usename and password of the seeded 'root' user.
  GOOD_USERNAME = "root"
  BAD_USERNAME = "bad"
  GOOD_PASSWORD = "password"
  BAD_PASSWORD = "dog no biscuit"
  GOOD_EMAIL = "Frank_root_user@davesag.com"
  BAD_EMAIL = "Frank_root_user@thisisnotavalidemailaddress.con"
  GOOD_PREFERENCE_TOKEN = "HTML_EMAIL"
  GOOD_PREFERENCE_VALUE = "false"
  BAD_PREFERENCE_TOKEN = "some old nonsense"

# just a dummy test that is needed for some reason
 def test_nothing
   return true
 end

 def setup_dummy_user (name)
   user = User.create( :username => name, :password => "password", :email => "Frank_Dummy_" + name + "@davesag.com")
   user.set_preference("HTML_EMAIL", "true")
   user.locale = "en"
   user.validated = true
   user.save!
 end
 
 def teardown_dummy_user(name)
   user = User.find_by_username(name)
   if user != nil
     user.destroy
   end
 end

end
