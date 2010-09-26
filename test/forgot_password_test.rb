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
    setup_dummy_user(dummy_name)

    get '/forgot_password'
    assert last_response.ok?
    assert last_response.body.include?('Provide your email address')
    
    post '/forgot_password', {:email => "Frank_Dummy_" + dummy_name + "@davesag.com"}
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

    # now try logging in with the new password
    post '/login', {:username => dummy_name, :password => "newpassword" }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as')    
    assert last_response.body.include?(dummy_name)    

    teardown_dummy_user("resetmypassword")
  end

end
