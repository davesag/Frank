#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'test/handler_test_base'

class SelfEditTest < HandlerTestBase

  def test_user_edit_own_profile
    george = setup_dummy_user("george")
    mildred = setup_dummy_user("mildred")
    
    # first log in george
    post '/login', { :username => "george", :password => GOOD_PASSWORD }
 
    # check the edit screen works
    get '/profile/edit'
    assert last_response.ok?
    assert last_response.body.include?( "frank_dummy_george@davesag.com")    

    # check email clash bounces
    post '/profile/edit', { :email => "frank_dummy_mildred@davesag.com", :password => "", :html_email => 'true'}
    assert last_response.ok?
    assert last_response.body.include?( "already exists")    

    # otherwsie all ok
    post '/profile/edit', { :email => "frank_dummy_all_okay@davesag.com", :password => "", :html_email => 'true'}
    assert last_response.ok?
    assert last_response.body.include?( "A confirmation email has been sent to")    

    # edit again, changing locale and html email preference.
    post '/profile/edit', { :email => "frank_dummy_all_okay@davesag.com", :locale => 'fr', :html_email => 'false', :password => ""}
    assert last_response.ok?
    assert last_response.body.include?( "sauvegardés")    

    george = User.find_by_username('george')
    assert george.locale == 'fr'
    assert george.get_preference('HTML_EMAIL').value == 'false'

    # edit again, changing locale back, not changing html email preference, but updating password
    post '/profile/edit', { :email => "frank_dummy_all_okay@davesag.com", :locale => 'en', :html_email => 'false', :password => "adifferentpassword"}
    assert last_response.ok?
    assert last_response.body.include?( "saved")    

    # edit again, changing nothing
    post '/profile/edit', { :email => "frank_dummy_all_okay@davesag.com", :locale => 'en', :html_email => 'false', :password => ""}
    assert last_response.ok?
    assert last_response.body.include?( "No changes made")    

    teardown_dummy_user("mildred")
    teardown_dummy_user("george")
  end

end
