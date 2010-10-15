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
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => NOBODY_USERNAME, :password => GOOD_PASSWORD }

    get '/users'
    assert last_response.redirect?
  end

  # test an admin can list users
  def test_logged_in_admin_can_list_users
    # first log in
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get '/users'
    assert last_response.ok?
    assert last_response.body.include?('There are 2 users')
  end

  # test an admin can show a specific user's details.
  def test_admin_can_show_user
    # first log in
    get '/login'  # need to do this to set up the form container.
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
    
    #first create an admin
    ann_admin = setup_dummy_user('anneadmin')
    ann_admin.add_role('admin')
    ann_admin.save!
    
    # log ann_admin in
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => 'anneadmin', :password => GOOD_PASSWORD }

    # ensure a request to edit and unknown ID is bounced.
    get "/user/edit/153"
    assert last_response.ok?
    assert last_response.body.include?("The user id supplied was not recognised")

    # ensure a command to update an unknown ID is bounced.
    post "/user/edit/153"
    assert last_response.ok?
    assert last_response.body.include?("The user id supplied was not recognised")

    # set up 2 dummy users
    george = setup_dummy_user("george")
    mildred = setup_dummy_user("mildred")
    
    # ensure we can bring up the edit screen for a user
    get "/user/edit/#{george.id}"
    assert last_response.ok?
    assert last_response.body.include?(george.username)
    assert last_response.body.include?(george.email)
    
    # check the mechanics of posting an update but change nothing just yet.
    pref = george.get_preference('HTML_EMAIL').value

    post "/user/edit/#{george.id}", { :email => george.email, :password => "", :_locale => george.locale,
      :html_email => pref, :roles => [''] }
    assert last_response.ok?
#    require 'ruby-debug'
#    debugger
    assert last_response.body.include?("no changes")
    
    # try changing george's html email preference only
    not_pref = pref == 'true' ? 'false' : 'true'
    post "/user/edit/#{george.id}", { :email => george.email, :password => "", :_locale => george.locale,
      :html_email => not_pref, :roles => [''] }
    assert last_response.ok?
    assert last_response.body.include?("User Details Saved")
    assert not_pref == george.get_preference('HTML_EMAIL').value
    
    # try changing george's email to mildred's
    post "/user/edit/#{george.id}", { :email => mildred.email, :password => "", :_locale => george.locale,
      :html_email => pref, :roles => [''] }
    assert last_response.ok?
    assert last_response.body.include?("Changes were not saved")
    
    # try changing george's email to something nice
    post "/user/edit/#{george.id}", { :email => "testytestgeorgegeorge@davesag.com", :password => "", :_locale => george.locale,
      :html_email => pref, :roles => [''] }
    assert last_response.ok?
    assert last_response.body.include?("User Details Saved")
    george.reload
    assert george.email == 'testytestgeorgegeorge@davesag.com'
    
    # try changing george's password and locale.
    post "/user/edit/#{george.id}", { :email => george.email, :password => "newpassword", :_locale => 'fr',
      :html_email => pref, :roles => [''] }
    assert last_response.ok?
    assert last_response.body.include?("User Details Saved")  # changing george's locale should not change the user's    
    george.reload
    assert george.locale == 'fr'

    # make up a new role to give George that is not a superuser role.
    special_role_one = Role.create(:name => 'special-role-one')
    special_role_two = Role.create(:name => 'special-role-two')

    # try making george a 'special-role-one' and a 'user'.
    post "/user/edit/#{george.id}", { :email => george.email, :password => "", :_locale => george.locale,
      :html_email => pref, :roles => ['special-role-one','user'] }
    assert last_response.ok?
    assert last_response.body.include?("User Details Saved") 
    george.reload
    assert george.has_role?('special-role-one')
    assert george.has_role?('user')
    assert !george.has_role?('special-role-two')
    assert george.locale == 'fr'
 
    # try making george just a 'user'.
    post "/user/edit/#{george.id}", { :email => george.email, :password => "", :_locale => george.locale,
      :html_email => pref, :roles => ['user'] }
    assert last_response.ok?
    assert last_response.body.include?("User Details Saved") 
    george.reload
    assert !george.has_role?('special-role-one')
    assert george.has_role?('user')
    assert !george.has_role?('special-role-two')
    assert george.locale == 'fr'
    
    # now try making george an 'admin'
    post "/user/edit/#{george.id}", { :email => george.email, :password => "", :_locale => george.locale,
      :html_email => pref, :roles => ['admin'] }
    assert last_response.ok?
    assert last_response.body.include?("User Details Saved") 
    george.reload
    assert !george.has_role?('special-role-one')
    assert !george.has_role?('user')
    assert !george.has_role?('special-role-two')
    assert george.has_role?('admin')
    assert george.locale == 'fr'

    get '/logout'
    
    # try logging george in with his new password
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => george.username, :password => "newpassword" }
    assert last_response.body.include?('Vous avez ouvert une session comme')    # we changed him to French.
    assert last_response.body.include?(george.username)    
    assert last_response.body.include?('Utilisateurs de liste')                 # we made him an Admin
    
    # okay now let's test make mildred an admin and test that george can't edit mildred or root
    mildred.add_role('admin')
    mildred.save!
    
    pref = mildred.get_preference('HTML_EMAIL').value
    
    # try changing mildred's email to something nice will bounce.

    post "/user/edit/#{mildred.id}", { :email => "testytestmildredpierce@davesag.com", :password => "", :_locale => mildred.locale,
      :html_email => pref, :roles => [''] }
    assert last_response.ok?         
    assert last_response.body.include?("Vous n'avez pas le droit d'éditer cet utilisateur")
    
    get '/logout'
    assert last_response.ok?

    # next we test that root (a superuser) can edit mildred (an admin)
    post '/login', { :username => 'root', :password => GOOD_PASSWORD }
    assert last_response.ok?
    
#    require 'ruby-debug'
#    debugger

    # the edit will be to make mildred a superuser.  Currently this is also something an admin can do to anyone but other admins.
    # TODO: This of course means a corrupt admin could create a fake user for another email address they own, with superuser access. 
    #        To close this loophole only superusers ought to be able to assign someone a superuser role.
    #       admins may not assign anyone a superuser role.
    post "/user/edit/#{mildred.id}", { :email => "testytestmildredpierce@davesag.com", :password => "", :_locale => mildred.locale,
      :html_email => pref, :roles => ['admin', 'superuser'] }
    assert last_response.ok?
    assert last_response.body.include?('User Details Saved')
    
    #    require 'ruby-debug'
    #    debugger

    mildred.reload
    assert mildred.has_role?('admin')
    assert mildred.has_role?('superuser')
    assert mildred.email == 'testytestmildredpierce@davesag.com'
    
    # finally we test that root can edit another superuser.  So now that is a mildred a superuser root should edit her.
    # in this case change her email and remove her from the superuser role, but leave her as an admin.
    post "/user/edit/#{mildred.id}", { :email => "taketwofortestymildred@davesag.com", :password => "", :_locale => mildred.locale,
      :html_email => pref, :roles => ['admin'] }
    assert last_response.ok?
    assert last_response.body.include?('User Details Saved')
    mildred.reload
    assert mildred.has_role?('admin')
    assert !mildred.has_role?('superuser')
    assert mildred.email == 'taketwofortestymildred@davesag.com'
    
    get '/logout'
    assert last_response.ok?
    
    # now finally test that mildred, as an admin, can't edit root, a superuser.
    root = User.find_by_username('root')
    post '/login', {:username => 'mildred', :password => GOOD_PASSWORD }
    assert last_response.ok?

    post "/user/edit/#{root.id}", { :email => "changeisasgoodasaholiday@davesag.com", :password => "", :_locale => root.locale,
      :html_email => pref, :roles => ['admin','superuser'] }
    assert last_response.ok?

    assert last_response.body.include?('You do not have permission to edit that user')
    
    get '/logout'
    assert last_response.ok?

    
    
    # clean up database at the end of the test
    special_role_two.destroy
    special_role_one.destroy
    mildred.destroy
    george.destroy
    ann_admin.destroy
  end

  # test an admin can show a specific user's details.
  def test_admin_can_delete_user
    george = setup_dummy_user("george")
    
    # first log in
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    user_id = User.find_by_username("george").id

    post "/user/delete/#{user_id}"
    assert last_response.ok?
    assert last_response.body.include?("has been deleted")
    assert User.find_by_username("george") ==  nil

    # Try that again and we should get a 'user unknown' error
    post "/user/delete/#{user_id}"
    assert last_response.ok?
    assert last_response.body.include?("The user id supplied was not recognised")
  end
  
  # test an admin can't delete a user with role 'superuser'
  def test_admin_cant_delete_superuser
    super_george = setup_dummy_user("super_george")
    super_george.add_role('superuser')
    super_george.save!

    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    post "/user/delete/#{super_george.id}"
    assert last_response.ok?
    assert last_response.body.include?("You can not delete a superuser")
    assert User.find_by_username("super_george") !=  nil
    
    # clean up database at the end of the test
    super_george.destroy
  end
  
  def test_admin_can_create_user
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get '/user'
    assert last_response.ok?
    assert last_response.body.include?("Add a new User")
    
    post '/user', { :username => "new_user", :password => GOOD_PASSWORD,
      :email => "new_user_franktest@davesag.com", :_locale => "en", :html_email => 'true', :roles => [''] }
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
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get '/user'  # need to do this to set up the form container.
    post '/user', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD,
      :email => "new_user_franktest@davesag.com", :_locale => "en", :html_email => 'true', :roles => [''] }
    assert last_response.ok?
    assert last_response.body.include?("A user with username '#{GOOD_USERNAME}' is already registered")
 
    post '/user', { :username => "new_username", :password => GOOD_PASSWORD,
      :email => GOOD_EMAIL, :_locale => "en", :html_email => 'true', :roles => [''] }
    assert last_response.ok?

#    require 'ruby-debug'
#    debugger

    assert last_response.body.include?("A user with email #{GOOD_EMAIL} is already registered")
 
  end
  
end
