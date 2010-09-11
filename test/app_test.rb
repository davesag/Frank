#!usr/bin/ruby

require 'app'
require 'test/unit'
require 'rack/test'
require 'models/user'

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
  BAD_EMAIL = "Frank_root_user@thisisnotavalidemailaddress.con"
  GOOD_PREFERENCE_TOKEN = "HTML_EMAIL"
  GOOD_PREFERENCE_VALUE = "false"
  BAD_PREFERENCE_TOKEN = "some old nonsense"
  
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

  # test that guests who try to sail on in to /in/index get bounced

  def test_guest_access_to_userland_gives_login_screen
    get '/in/index'
    follow_redirect!
    
    assert last_request.url.ends_with?("/login")
    assert last_response.ok?
    assert last_response.body.include?('log in to continue')   
  end

  # test for user login with bad credentials

  def test_login_attempt_bad_username_gives_login_screen
    post '/login', { :username => BAD_USERNAME, :password => BAD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination, please try again')    
  end

  def test_login_attempt_bad_email_gives_login_screen
    post '/login', { :username => BAD_EMAIL, :password => BAD_PASSWORD }
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
    assert last_response.body.include?('You are logged in as root')    
  end

  def test_login_attempt_good_email_and_password_gives_user_home_screen
    post '/login', {:username => GOOD_EMAIL, :password => GOOD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as root')    
  end

  def test_logout_user_gives_home_screen
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # then log out again
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('Please log in again to continue')    
  end

  # test that logged in users are allowed into userland

  def test_logged_in_user_access_to_userland_approved
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # then specifically request the index page in userland
    get '/in/index'
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as root')    
  end
  
  # test that the logged in user's prferences are able to be set and retrieved.
  
  def test_users_preferences
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # the show user page dumps all of the preferences.
    get '/in/show_user'
    assert last_response.ok?
    assert last_response.body.include?( GOOD_PREFERENCE_TOKEN)    
    assert last_response.body.include?( GOOD_PREFERENCE_VALUE)    
    assert !last_response.body.include?( BAD_PREFERENCE_TOKEN)    

  end

  # test user registration form appears when requested
  def test_guest_access_to_registration_form_okay
    get '/register'
    assert last_response.ok?
    assert last_response.body.include?('Registration is fast and free')
  end

  # test user registration form bypassed if already logged in
  def test_logged_in_user_access_to_registration_form_skipped
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get '/register'
    assert last_response.ok?
    assert last_response.body.include?('You are already logged in')
  end

  # test logged in user can't post to /registration 
  def test_logged_in_user_access_to_registration_form_skipped
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    post '/registration', { :username => "any", :password => "any", :email => "any@any.any" }
    assert last_response.ok?
    assert last_response.body.include?('You are already logged in')
  end

  # test user registration of a user with a known username gives an error and shows registration page again
  def test_register_known_username_gives_error
    post '/registration', { :username => GOOD_USERNAME, :password => "any", :email => "any@any.any" }
    assert last_response.ok?
    assert last_response.body.include?(GOOD_USERNAME + "' already exists")
  end
  
  # test user registration of a user with a known email gives an error and shows registration page again
  def test_register_known_email_gives_error
    post '/registration', { :username => "any", :password => "any", :email => GOOD_EMAIL }
    assert last_response.ok?
    assert last_response.body.include?(GOOD_EMAIL + "' already exists")
  end
  
  # test user registration of a user with a unique username and email is okay
  def test_register_unique_username_and_email_is_ok
    post '/registration', { :username => "unique_test", :password => "test_pass", :email => "unique_frank_test@davesag.com" }
    assert last_response.ok?
    assert last_response.body.include?("A confirmation email has been sent to unique_frank_test@davesag.com")
    # here we could also test the whole email cycle.
    # for now once a user is registered they can log in.  change this test when the email of a rego link is done.
    
    # can the new user log in?
    post '/login', { :username => "unique_test", :password => "test_pass" }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as unique_test')    

    # now clean the test crud from the database
    post '/delete_self'
    assert last_response.ok?
    assert last_response.body.include?('Your user record has been deleted. You must register again to log in')
    assert User.find_by_username("unique_test") == nil
  end

  # test a logged out user can't delete_self
  def test_guest_cant_delete_self
    post '/delete_self'
    assert last_response.ok?
    assert last_response.body.include?('You are not logged in')
  end

end
