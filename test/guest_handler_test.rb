#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'test/handler_test_base'

class GuestHandlerTest < HandlerTestBase

# test basic guest level requests

  def test_default_guest_gives_login_screen
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('Login to continue')
  end

  def test_login_guest_gives_login_screen
    get '/login'
    assert last_response.ok?
    assert last_response.body.include?('Login to continue')
  end

  def test_logout_guest_gives_login_screen
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('Login to continue')    
  end

  # test that guests who try to sail on in to /in/index get bounced

  def test_guest_access_to_userland_gives_login_screen
    get '/in/index'
    follow_redirect!

    assert last_request.url.ends_with?("/login")
    assert last_response.ok?
    assert last_response.body.include?('Login to continue')   
  end

  # test for user login with bad credentials

  def test_login_attempt_bad_username_gives_login_screen
    post '/login', { :username => BAD_USERNAME, :password => BAD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination. Please try again')    
  end

  def test_login_attempt_bad_email_gives_login_screen
    post '/login', { :username => BAD_EMAIL, :password => BAD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination. Please try again')    
  end

  def test_login_attempt_good_username_and_bad_password_gives_login_screen
    post '/login', { :username => GOOD_USERNAME, :password => BAD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination. Please try again')    
  end

  def test_login_attempt_good_email_and_bad_password_gives_login_screen
     post '/login', { :username => GOOD_EMAIL, :password => BAD_PASSWORD }
     assert last_response.ok?
     assert last_response.body.include?('Unknown User/Password combination. Please try again')    
   end

  # test a logged out user can't delete_self
  def test_guest_cant_delete_self
    post '/delete_self'
    assert last_response.ok?
    assert last_response.body.include?('You are not logged in')
  end

end
