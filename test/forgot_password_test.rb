#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'test/handler_test_base'

class ForgotPasswordTest < HandlerTestBase

  def test_password_reset
    dummy_name = "resetmypassword"
    dummy_user = setup_dummy_user(dummy_name)

    get '/forgot_password'
    assert last_response.ok?
    assert last_response.body.include?('Provide your email address')
    
    post '/forgot_password', {:email => "frank_dummy_" + dummy_name + "@davesag.com"}
    assert last_response.ok?
    assert last_response.body.include?('Check your email')
    
    token = User.find_by_username(dummy_name).validation_token
    assert token != nil

    get '/reset_password/' + token
    assert last_response.ok?
    assert last_response.body.include?('Update password')

    post '/reset_password', {:token => token, :password => "newpassword"}
    assert last_response.ok?
    assert last_response.body.include?("Your password has been reset")

    new_token = User.find_by_username(dummy_name).validation_token
    assert token != new_token
    
    # testing for malicious use prevention
    # check coming in with the same token fails
    get '/reset_password/' + token
    assert last_response.ok?
    assert last_response.body.include?('Token expired')

    # posting with a made up token won't work as you have to brig up the get screen first to prep the form container.
    post '/reset_password', {:token => token, :password => "newpassword"}
    assert last_response.ok?
    assert last_response.body.include?('There were errors in your form')

    # and for the truly paranoid, say someone guessed the user's new token (or snooped it somehow?)
    get '/reset_password/' + new_token
    assert last_response.ok?
    assert last_response.body.include?('Token expired')

    post '/reset_password', {:token => new_token, :password => "newpassword"}
    assert last_response.ok?
    assert last_response.body.include?('There were errors in your form')

    # now try logging in with the new password
    post '/login', {:username => dummy_name, :password => "newpassword" }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as')    
    assert last_response.body.include?(dummy_name)    

    teardown_dummy_user("resetmypassword")
  end

  def test_lost_password_while_logged_in_gives_error
    get '/login'  # need to do this to set up the form container.
    post '/login', {:username => GOOD_USERNAME, :password => GOOD_PASSWORD }
    assert last_response.ok?

    get '/forgot_password'
    assert last_response.ok?
    assert last_response.body.include?('You are still logged in as')

    post '/forgot_password'
    assert last_response.ok?
    assert last_response.body.include?('You are still logged in as')
    
    get '/logout'
    assert last_response.ok?    
  end

  def test_lost_password_wrong_email_gives_error
    get '/forgot_password'
    post '/forgot_password', { :email => BAD_EMAIL }
    assert last_response.ok?
    assert last_response.body.include?('That email address is unknown.')
  end

end
