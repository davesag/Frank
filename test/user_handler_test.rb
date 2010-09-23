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
    assert last_response.body.include?('Please log in again to continue')    

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

  def test_edit_user_email_clashes
    setup_dummy_user("George")
    setup_dummy_user("Mildred")
    
    # first log in
    post '/login', { :username => "George", :password => GOOD_PASSWORD }
 
    get '/in/edit_user'
    assert last_response.ok?
    assert last_response.body.include?( "Frank_Dummy_George@davesag.com")    

    post '/in/editing_user', { :email => "Frank_Dummy_Mildred@davesag.com", :password => "", :html_email => 'true'}
    assert last_response.ok?
    assert last_response.body.include?( "already exists")    

    post '/in/editing_user', { :email => "Frank_Dummy_All_Okay@davesag.com", :password => "", :html_email => 'true'}
    assert last_response.ok?
    assert last_response.body.include?( "A confirmation email has been sent to")    

    post '/in/editing_user', { :email => "Frank_Dummy_All_Okay@davesag.com", :password => "newpassword", :html_email => 'true'}
    assert last_response.ok?
    assert last_response.body.include?( "saved")    

    teardown_dummy_user("Mildred")
    teardown_dummy_user("George")
  end

 def setup_dummy_user (name)
   user = User.create( :username => name, :password => "password", :email => "Frank_Dummy_" + name + "@davesag.com")
   user.set_preference("HTML_EMAIL", "true")
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
