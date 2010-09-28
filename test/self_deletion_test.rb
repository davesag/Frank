#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'test/handler_test_base'

class SelfDeletionTest < HandlerTestBase

  def test_self_deletion
    dummy_user = setup_dummy_user("deleteme")

    # first log in
    post '/login', { :username => "deleteme", :password => GOOD_PASSWORD }
    
    post '/delete_self'    
    assert last_response.ok?
    assert last_response.body.include?("Are you sure")    

    post '/delete_self', {:frankie_says_force_it => 'true'}
    assert last_response.ok?
    assert last_response.body.include?("deleted")
    
    assert User.find_by_username("deleteme") == nil
  end

  def test_cant_delete_root

    # first log in as root (an admin user - see db/seeds.rb)
    post '/login', { :username => "root", :password => GOOD_PASSWORD }
    
    post '/delete_self'
    assert last_response.ok?
    assert last_response.body.include?("An Administrator can not be deleted")    

    post '/delete_self', {:frankie_says_force_it => 'true'}
    assert last_response.ok?
    assert last_response.body.include?("An Administrator can not be deleted")    
    
    assert User.find_by_username("root") != nil
  end

end
