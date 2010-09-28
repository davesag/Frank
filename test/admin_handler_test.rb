#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'models/role'
require 'test/handler_test_base'

class AdminHandlerTest < HandlerTestBase

  # test a guest can't list users
  def test_guest_cant_list_users
    get '/users'
    assert last_response.redirect?
  end

  # test a user who is not an admin can't list users
  def test_non_admin_user_cant_list_users
    # first log in
    post '/login', { :username => NOBODY_USERNAME, :password => GOOD_PASSWORD }

    get '/users'
    assert last_response.redirect?
  end

  # test an admin can list users
  def test_logged_in_admin_can_list_users
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get '/users'
    assert last_response.ok?
    assert last_response.body.include?('There are 2 users')
  end

  # test an admin can show a specific user's details.
  def test_admin_can_show_user
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    user_id = User.find_by_username(NOBODY_USERNAME).id

    get "/user/#{user_id}"
    assert last_response.ok?
    assert last_response.body.include?(NOBODY_USERNAME)

    # ensure a request for unknown ID is bounced.
    get "/user/153"
    assert last_response.ok?
    assert last_response.body.include?("The user id supplied was not recognised")

  end

  # test an admin can edit a specific user's details.
  def test_admin_can_edit_a_user
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # ensure a request to edit and unknown ID is bounced.
    get "/user/edit/153"
    assert last_response.ok?
    assert last_response.body.include?("The user id supplied was not recognised")

    # ensure a command to update an unknown ID is bounced.
    post "/user/edit/153"
    assert last_response.ok?
    assert last_response.body.include?("The user id supplied was not recognised")

    # set up 2 dummy users
    george = setup_dummy_user("George")
    mildred = setup_dummy_user("Mildred")
    
    # ensure we can bring up the edit screen for a user
    get "/user/edit/#{george.id}"
    assert last_response.ok?
    assert last_response.body.include?(george.username)
    assert last_response.body.include?(george.email)
    
    # check the mechanics of posting an update but change nothing just yet.
    pref = george.get_preference('HTML_EMAIL').value

    post "/user/edit/#{george.id}", { :email => george.email, :password => "", :_locale => george.locale,
      :html_email => pref }
    assert last_response.ok?
    assert last_response.body.include?("no changes")
    
    # try changing george's html email preference only
    post "/user/edit/#{george.id}", { :email => george.email, :password => "", :_locale => george.locale,
      :html_email => pref == 'true' ? 'false' : 'true' }
    assert last_response.ok?
    assert last_response.body.include?("User Details Saved")
    
    # try changing george's email to mildred's
    post "/user/edit/#{george.id}", { :email => mildred.email, :password => "", :_locale => george.locale,
      :html_email => pref }
    assert last_response.ok?
    assert last_response.body.include?("Changes were not saved")
    
    # try changing george's email to something nice
    post "/user/edit/#{george.id}", { :email => "testytestFrankFrank@davesag.com", :password => "", :_locale => george.locale,
      :html_email => pref }
    assert last_response.ok?
    assert last_response.body.include?("User Details Saved")  # changing George's locale should not change the user's    
    
    # try changing george's password and locale.
    post "/user/edit/#{george.id}", { :email => george.email, :password => "newpassword", :_locale => 'fr',
      :html_email => pref }
    assert last_response.ok?
    assert last_response.body.include?("User Details Saved")  # changing George's locale should not change the user's    

    get '/logout'
    
    # try logging George in with his new password
    post '/login', { :username => george.username, :password => "newpassword" }
    assert last_response.body.include?('Vous avez ouvert une session comme')    # we changed him to French.
    assert last_response.body.include?(george.username)    
    
    # clean up database at the end of the test
    mildred.destroy
    george.destroy

  end

  # test an admin can show a specific user's details.
  def test_admin_can_delete_user
    george = setup_dummy_user("George")
    
    # first log in
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    user_id = User.find_by_username("George").id

    post "/user/delete/#{user_id}"
    assert last_response.ok?
    assert last_response.body.include?("has been deleted")
    assert User.find_by_username("George") ==  nil

    # Try that again and we should get a 'user unknown' error
    post "/user/delete/#{user_id}"
    assert last_response.ok?
    assert last_response.body.include?("The user id supplied was not recognised")
  end
  
  # test an admin can't delete a user with role 'superuser'
  def test_admin_cant_delete_superuser
    super_george = setup_dummy_user("Super George")
    super_george.add_role('superuser')
    super_george.save!

    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    post "/user/delete/#{super_george.id}"
    assert last_response.ok?
    assert last_response.body.include?("You can not delete a superuser")
    assert User.find_by_username("Super George") !=  nil
    
    # clean up database at the end of the test
    super_george.destroy
  end
  
  def test_admin_can_create_user
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get '/user'
    assert last_response.ok?
    assert last_response.body.include?("Add a new User")
    
    post '/user', { :username => "new_user", :password => GOOD_PASSWORD,
      :email => "new_user_Franktest@davesag.com", :_locale => "en", :html_email => 'true' }
    assert last_response.ok?
    assert last_response.body.include?("You have added a user called 'new_user'")
    
    new_user = User.find_by_username('new_user')
    
    # test that this user can now log in.
    get '/logout'
    assert last_response.ok?

    post '/login', { :username => new_user.username, :password => GOOD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as')    
    assert last_response.body.include?(new_user.username)    
    
    new_user.destroy
    
  end

  def test_created_user_dupe_username_password
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    post '/user', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD,
      :email => "new_user_Franktest@davesag.com", :_locale => "en", :html_email => 'true' }
    assert last_response.ok?
    assert last_response.body.include?("A user with username '#{GOOD_USERNAME}' is already registered")
 
    post '/user', { :username => "new_username", :password => GOOD_PASSWORD,
      :email => GOOD_EMAIL, :_locale => "en", :html_email => 'true' }
    assert last_response.ok?
    assert last_response.body.include?("A user with email #{GOOD_EMAIL} is already registered")
 
  end
  
end
