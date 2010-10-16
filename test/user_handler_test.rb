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
    get '/login'  # need to do this to set up the form container.
    assert last_response.ok?
    post '/login', {:username => GOOD_USERNAME, :password => GOOD_PASSWORD }
    assert last_response.ok?
    assert last_response.body.include?('You are logged in as')    
    assert last_response.body.include?(GOOD_USERNAME)    
  end

  def test_login_attempt_good_email_and_password_gives_user_home_screen
    get '/login'  # need to do this to set up the form container.
    assert last_response.ok?
    post '/login', {:username => GOOD_EMAIL, :password => GOOD_PASSWORD }
    assert last_response.ok?
    
#    require 'ruby-debug'
#    debugger
    
    assert last_response.body.include?('You are logged in as')    
    assert last_response.body.include?(GOOD_USERNAME)    
  end

  def test_logout_user_gives_home_screen
    # first log in
    get '/login'  # need to do this to set up the form container.
    assert last_response.ok?
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # try going to '/'
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('Welcome back')

    # try going to '/login' again
    get '/login'
    assert last_response.ok?
    assert last_response.body.include?('Welcome back')

    # try going to '/register' as a logged in user
    get '/register'
    assert last_response.ok?
    assert last_response.body.include?('You are already logged in as')

    # then log out
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('Login again to continue')    

    # try going to '/register' as a logged out but remembered user
    get '/register'
    assert last_response.ok?
    assert last_response.body.include?('Logout completely before trying to register a new user')

    # then log out again
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('logged out completely')    
  end

  def test_various_mixed_public_private_pages
    # try going to '/terms' as a guest
    get '/terms'
    assert last_response.ok?
    assert last_response.body.include?('Terms & Conditions')
 
    # try going to '/privacy' as a guest
    get '/privacy'
    assert last_response.ok?
    assert last_response.body.include?('Privacy is important')
 
    # try going to '/contact' as a guest
    get '/contact'
    assert last_response.ok?
    assert last_response.body.include?('Contact Details')

    # now log in and try again
    get '/login'  # need to do this to set up the form container.
    assert last_response.ok?
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }
    assert last_response.ok?

    # try going to '/terms' as a logged in user
    get '/terms'
    assert last_response.ok?
    assert last_response.body.include?('The Terms & Conditions you agreed to when you registered')

    # try going to '/privacy' as a logged in user
    get '/privacy'
    assert last_response.ok?
    assert last_response.body.include?('We take privacy seriously')

    # try going to '/contact' as a logged in user
    get '/contact'
    assert last_response.ok?
    assert last_response.body.include?('Get In Touch')

    # then log out
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('Login again to continue')    

  end

  def test_contact_post
    #test as guest (will request an email address)
    get '/contact'
    post '/contact', { :subject => "testing", :email => "franktestguest@davesag.com", :message => "Hi there, you are awesome."}
    assert last_response.ok?
    assert last_response.body.include?('Your message has been emailed to the Webmaster')
    
    # then login
    get '/login'  # need to do this to set up the form container.
    assert last_response.ok?
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # then test as user (will not have to ask for an email address)
    get '/contact'
    post '/contact', { :subject => "testing", :email => "franktestguest@davesag.com", :message => "Hi there, you are awesome."}
    assert last_response.ok?
    assert last_response.body.include?('Your priority message has been emailed to the Webmaster')

  end

  # there is a translation of the terms page for eu-au and en
  # the en/terms.haml should load for a GB user and the en-au/terms.haml should load for an AU user.
  def test_localised_template_loads
    george = setup_dummy_user("George")
    george.locale = 'en-GB'
    george.save!

    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => george.username, :password => GOOD_PASSWORD }
    assert last_response.ok?
    
    get '/terms'
    assert last_response.ok?
    assert last_response.body.include?('Demonstration Framework')  # 'en' locale version.
    
    get '/privacy'
    assert last_response.ok?
    assert last_response.body.include?('We will use best efforts to keep users data private')  # default version.
    
    get '/logout'
    
    mildred = setup_dummy_user("Mildred")
    mildred.locale = 'en-AU'
    mildred.save!

    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => mildred.username, :password => GOOD_PASSWORD }
    assert last_response.ok?
    
    get '/terms'
    assert last_response.ok?
    assert last_response.body.include?('This website is a demo framework only')  # 'en-au' locale version.

    get '/privacy'
    assert last_response.ok?
    assert last_response.body.include?("We'll use our very best efforts to keep our users' data private")  # 'en-au' locale version.
    
    get '/logout'

    mildred.destroy
    george.destroy
  end


  # test that logged in users are allowed into userland

  def test_logged_in_user_access_to_userland_approved
    # first log in
    get '/login'  # need to do this to set up the form container.
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
    get '/login'  # need to do this to set up the form container.
    post '/login', { :username => GOOD_USERNAME, :password => GOOD_PASSWORD }

    # the show user page dumps all of the preferences.
    get '/profile'
    assert last_response.ok?
    assert last_response.body.include?( GOOD_PREFERENCE_TOKEN)    
    assert last_response.body.include?( GOOD_PREFERENCE_VALUE)    
    assert !last_response.body.include?( BAD_PREFERENCE_TOKEN)    

  end

end
