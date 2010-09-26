#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'test/handler_test_base'

class RegistrationHandlerTest < HandlerTestBase

  # test user registration form appears when requested
  def test_guest_access_to_registration_form_okay
    get '/register'
    assert last_response.ok?
    assert last_response.body.include?('Registration is easy and free')
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

    # can the new user log in?  not yet! has not validated.
    post '/login', { :username => "unique_test", :password => "test_pass" }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination. Please try again')    

    v_token = User.find_by_username("unique_test").validation_token
    get '/validate/' + v_token
    assert last_response.ok?
    assert last_response.body.include?('Your registration has been confirmed')    
    assert v_token != User.find_by_username("unique_test").validation_token

    # can the new user log in?  should be ok now
    post '/login', { :username => "unique_test", :password => "test_pass" }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in')    
    assert last_response.body.include?("unique_test")    

    # now clean the test crud from the database
    post '/delete_self', {:frankie_says_force_it => 'true'}
    assert last_response.ok?
    assert last_response.body.include?('deleted')
    assert User.find_by_username("unique_test") == nil
  end

end
