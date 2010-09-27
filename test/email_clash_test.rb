#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'test/handler_test_base'

class EmailClashTest < HandlerTestBase

  def test_edit_user_email_clashes
    setup_dummy_user("George")
    setup_dummy_user("Mildred")
    
    # first log in
    post '/login', { :username => "George", :password => GOOD_PASSWORD }
 
    get '/profile/edit'
    assert last_response.ok?
    assert last_response.body.include?( "Frank_Dummy_George@davesag.com")    

    post '/profile/edit', { :email => "Frank_Dummy_Mildred@davesag.com", :password => "", :html_email => 'true'}
    assert last_response.ok?
    assert last_response.body.include?( "already exists")    

    post '/profile/edit', { :email => "Frank_Dummy_All_Okay@davesag.com", :password => "", :html_email => 'true'}
    assert last_response.ok?
    assert last_response.body.include?( "A confirmation email has been sent to")    

    post '/profile/edit', { :email => "Frank_Dummy_All_Okay@davesag.com", :password => "newpassword", :html_email => 'true'}
    assert last_response.ok?
    assert last_response.body.include?( "saved")    

    teardown_dummy_user("Mildred")
    teardown_dummy_user("George")
  end

end
