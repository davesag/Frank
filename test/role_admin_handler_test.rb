#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'test/handler_test_base'

class RoleAdminHandlerTest < HandlerTestBase

  # test a guest can't list roles
  def test_guest_cant_list_roles
    get '/roles'
    assert last_response.redirect?
  end

  # test a user who is not an admin can't list roles
  def test_non_admin_cant_list_roles
    # first log in
    get '/login'
    post '/login', { :username => NOBODY_USERNAME, :password => GOOD_PASSWORD }

    get '/roles'
    assert last_response.redirect?
  end

  # test an admin can list users
  def test_logged_in_admin_can_list_roles
    # first log in
    get '/login'
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get '/roles'
    assert last_response.ok?
    assert last_response.body.include?('There are 3 roles')
  end

  # test an admin can edit a specific user's details.
  def test_admin_can_edit_a_role
    # first log in
    get '/login'
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # ensure a request to edit and unknown ID is bounced.
    get "/role/edit/bogus"
    assert last_response.ok?
    assert last_response.body.include?("The role name supplied was not recognised")

    # ensure a command to update an unknown ID is bounced.
    post "/role/edit/bogus"
    assert last_response.ok?
    assert last_response.body.include?("The role name supplied was not recognised")

    # set up a dummy role
    role = Role.create( :name => "dummy_role")
    
    # ensure we can bring up the edit screen for a user
    get "/role/edit/#{role.name}"
    assert last_response.ok?
    assert last_response.body.include?(role.name)
    
    # check the mechanics of posting an update but change nothing just yet.
    new_name = 'new_role_name'

    post "/role/edit/#{role.name}", { :new_name => role.name }
    assert last_response.ok?
    assert last_response.body.include?("no changes")
    
    # try changing role's name to something new
    post "/role/edit/#{role.name}", { :new_name => new_name }
    assert last_response.ok?
    assert last_response.body.include?("Role Saved")
    
    # try changing role's name to 'admin'
    post "/role/edit/#{new_name}", { :new_name => 'admin' }
    assert last_response.ok?
    assert last_response.body.include?("There is already a role called 'admin'")
    
    get '/logout'

    role.destroy

  end

  # test an admin can show a specific role's details.
  def test_admin_can_delete_role
    role = Role.create( :name => "dummy_role")
    
    # first log in
    get '/login'
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    post "/role/delete/#{role.name}"
    assert last_response.ok?
    assert last_response.body.include?("was deleted")
    assert Role.find_by_name(role.name) ==  nil

    # Try that again and we should get a 'role unknown' error
    post "/role/delete/#{role.name}"
    assert last_response.ok?
    assert last_response.body.include?("The role name supplied was not recognised")
  end
  
  # test an admin can't delete a blessed role.
  def test_admin_cant_delete_blessed_role
    super_role = Role.find_by_name('superuser')
    admin_role = Role.find_by_name('admin')

    get '/login'
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    post "/role/delete/#{super_role.name}"
    assert last_response.ok?
    assert last_response.body.include?("You can't delete the role '#{super_role.name}'")
    assert Role.find_by_name("#{super_role.name}") !=  nil
    
    post "/role/delete/#{admin_role.name}"
    assert last_response.ok?
    assert last_response.body.include?("You can't delete the role '#{admin_role.name}'")
    assert Role.find_by_name("#{admin_role.name}") !=  nil
    
  end

  # test an admin can't delete a blessed role.
  def test_admin_cant_edit_blessed_role
    super_role = Role.find_by_name('superuser')
    admin_role = Role.find_by_name('admin')

    get '/login'
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    get "/role/edit/#{super_role.name}"
    assert last_response.ok?
    assert last_response.body.include?("You can't edit the role '#{super_role.name}'")
    assert Role.find_by_name("#{super_role.name}") !=  nil
    
    get "/role/edit/#{admin_role.name}"
    assert last_response.ok?
    assert last_response.body.include?("You can't edit the role '#{admin_role.name}'")
    assert Role.find_by_name("#{admin_role.name}") !=  nil
    
    post "/role/edit/#{super_role.name}", { :new_name => 'something'}
    assert last_response.ok?
    assert last_response.body.include?("You can't edit the role '#{super_role.name}'")
    assert Role.find_by_name("#{super_role.name}") !=  nil
    
    post "/role/edit/#{admin_role.name}", { :new_name => 'something'}
    assert last_response.ok?
    assert last_response.body.include?("You can't edit the role '#{admin_role.name}'")
    assert Role.find_by_name("#{admin_role.name}") !=  nil
  end

  def test_admin_can_create_role
    get '/login'
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }
 
    get '/role'
    assert last_response.ok?
    assert last_response.body.include?("Add a new Role")
    
    post '/role', {:new_name => "new_role"}
    assert last_response.ok?
    assert last_response.body.include?("Role 'new_role' created")
  
    # try again with the same name should give an error
    post '/role', {:new_name => "new_role"}
    assert last_response.ok?
    assert last_response.body.include?("A role called 'new_role' already exists")
    
    new_role = Role.find_by_name('new_role')
    new_role.destroy
    
  end

end
