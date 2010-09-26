#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'test/handler_test_base'

class UserHandlerTest < HandlerTestBase

   # test for user login with good credentials

  def test_login_attempt_good__username_and_password_gives_user_home_screen
    post '/login', {:username => GOOD_USERNAME, :password => GOOD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as')    
    assert last_response.body.include?(GOOD_USERNAME)    
  end

  def test_login_attempt_good_email_and_password_gives_user_home_screen
    post '/login', {:username => GOOD_EMAIL, :password => GOOD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as')    
    assert last_response.body.include?(GOOD_USERNAME)    
  end

  def test_logout_user_gives_home_screen
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # then log out
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('Login again to continue')    

    # then log out again
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('logged out completely')    
  end

  # test that logged in users are allowed into userland

  def test_logged_in_user_access_to_userland_approved
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # then specifically request the index page in userland
    get '/in/index'
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as')    
    assert last_response.body.include?(GOOD_USERNAME)    
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

end
