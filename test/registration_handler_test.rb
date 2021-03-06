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
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get '/register'
    assert last_response.ok?
    assert last_response.body.include?('You are already logged in')
  end

  # test logged in user can't post to /registration 
  def test_logged_in_user_access_to_registration_form_skipped
    # first log in
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get '/register'
    post '/registration', { :username => "anyuser", :password => "anypass", :terms => 'true', :locale => 'en', :email => "any@any.any" }
    assert last_response.ok?
    assert last_response.body.include?('You are already logged in')
  end

  # test user registration of a user with a known username gives an error and shows registration page again
  def test_register_known_username_gives_error
    get '/register'
    post '/registration', { :username => GOOD_USERNAME, :password => "anypass", :terms => 'true', :locale => 'en', :email => "any@any.any" }
    assert last_response.ok?
    assert last_response.body.include?(GOOD_USERNAME + "' already exists")
  end

  # test user registration of a user with a known email gives an error and shows registration page again
  def test_register_known_email_gives_error
    get '/register'
    post '/registration', { :username => "anyuser", :password => "anypass", :terms => 'true', :locale => 'en', :email => GOOD_EMAIL }
    assert last_response.ok?
    assert last_response.body.include?(GOOD_EMAIL + "' already exists")
  end

  # test trying to register without accepting terms gives an error and shows the registration page again
  def test_register_unique_username_and_email_but_no_terms
    get '/register'
    post '/registration', { :username => "unique_test", :password => "test_pass", :terms => 'false', :locale => 'en', :email => "unique_frank_test@davesag.com" }
    assert last_response.ok?
    assert last_response.body.include?("You must accept the terms & conditions")

    # what if there is no terms param supplied at all?
    post '/registration', { :username => "unique_test", :password => "test_pass", :locale => 'en', :email => "unique_frank_test@davesag.com" }
    assert last_response.ok?
    assert last_response.body.include?("You must accept the terms & conditions")

    # what if the terms param supplied is nonsense?
    post '/registration', { :username => "unique_test", :password => "test_pass", :terms => 'nonsense', :locale => 'en', :email => "unique_frank_test@davesag.com" }
    assert last_response.ok?
    assert last_response.body.include?("You must accept the terms & conditions")

  end

  # test user registration of a user with a unique username and email is okay
  def test_register_unique_username_and_email_is_ok
    get '/register'
    post '/registration', { :username => "unique_test", :password => "test_pass", :terms => 'true', :locale => 'en', :email => "unique_frank_test@davesag.com" }
    assert last_response.ok?
    assert last_response.body.include?("A confirmation email has been sent to unique_frank_test@davesag.com")

    # can the new user log in?  not yet! has not validated.
    get '/login'
    post '/login', { :username => "unique_test", :password => "test_pass" }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination. Please try again')    

    v_token = User.find_by_username("unique_test").validation_token
    get '/validate/' + v_token
    assert last_response.ok?
    assert last_response.body.include?('Your registration has been confirmed')    
    assert v_token != User.find_by_username("unique_test").validation_token

    new_v_token = User.find_by_username("unique_test").validation_token
    assert v_token != new_v_token

    # ensure the old token doesn't work
    get '/validate/' + v_token
    assert last_response.ok?
    assert last_response.body.include?('Token expired')    

    # can the new user log in?  should be ok now
    get '/login'
    post '/login', { :username => "unique_test", :password => "test_pass" }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in')    
    assert last_response.body.include?("unique_test")    

    # now clean the test crud from the database
    User.find_by_username("unique_test").destroy
  end

  # test setting a user's locale on registration works and changes the session locale
  def test_registering_user_with_changed_locale
    get '/register'
    post '/registration', { :username => "unique_test", :password => "test_pass", :terms => 'true', :locale => 'fr', :email => "unique_frank_test@davesag.com" }
    assert last_response.ok?
    assert last_response.body.include?("Un email de confirmation")
    
    # now clean the test crud from the database
    User.find_by_username("unique_test").destroy
  end

  # test setting a user's locale on registration works and changes the session locale
  def test_registering_user_with_unknown_locale_gives_default
    get '/register'
    post '/registration', { :username => "unique_test", :password => "test_pass", :terms => 'true', :locale => 'timbucktu', :email => "unique_frank_test@davesag.com" }
    assert last_response.ok?
    assert last_response.body.include?("A confirmation email has been sent")  # in english if you please.

    # now clean the test crud from the database
    User.find_by_username("unique_test").destroy
  end

end
