#!usr/bin/ruby

require 'app'
require 'test/unit'
require 'rack/test'

set :environment, :test

class AppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

# see db/seeds.rb for the usename and password of the seeded 'root' user.
  GOOD_USERNAME = "root"
  BAD_USERNAME = "bad"
  GOOD_PASSWORD = "password"
  BAD_PASSWORD = "dog no biscuit"
  GOOD_EMAIL = "Frank_root_user@davesag.com"
  BAD_EMAIL = "mrcreepy@thisisnotavalidemailaddress.con"

# test basic guest level requests

  def test_default_guest_gives_login_screen
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('log in to continue')
  end

  def test_login_guest_gives_login_screen
    get '/login'
    assert last_response.ok?
    assert last_response.body.include?('log in to continue')    
  end

  def test_logout_guest_gives_login_screen
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('log in to continue')    
  end

# now test for user login with bad credentials

  def test_login_attempt_bad_username_gives_login_screen
    post '/login', { :username => BAD_USERNAME, :password => BAD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination, please try again')    
  end

  def test_login_attempt_bad_email_gives_login_screen
    post '/login', { :username => 'bad@test.com', :password => BAD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination, please try again')    
  end

  def test_login_attempt_good_username_and_bad_password_gives_login_screen
    post '/login', { :username => GOOD_USERNAME, :password => BAD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination, please try again')    
  end

  def test_login_attempt_good_email_and_bad_password_gives_login_screen
     post '/login', { :username => GOOD_EMAIL, :password => BAD_PASSWORD }
     assert last_response.ok?
     assert last_response.body.include?('Unknown User/Password combination, please try again')    
   end

   # now test for user login with good credentials

  def test_login_attempt_good__username_and_password_gives_user_home_screen
    post '/login', {:username => GOOD_USERNAME, :password => GOOD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('Welcome root.')    
  end

  def test_login_attempt_good_email_and_password_gives_user_home_screen
    post '/login', {:username => GOOD_EMAIL, :password => GOOD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('Welcome root.')    
  end

  def test_logout_user_gives_home_screen
# first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }
# then log out again
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('Please log in again to continue')    
  end

end
