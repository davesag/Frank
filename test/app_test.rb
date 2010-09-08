#!usr/bin/ruby

require 'app'
require 'test/unit'
require 'rack/test'

set :environment, :test

class AppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_default_guest_gives_login_screen
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('log in to continue')
  end

  def test_login_guest_gives_login_screen
    get '/login'
    assert last_response.ok?
    assert last_response.body.include?('log in to continue')    
  end

  def test_logout_guest_gives_login_screen
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('log in to continue')    
  end

  def test_login_attempt_bad_credentials_gives_login_screen
    post '/login', { :username => 'bad', :password => 'dognobiscuit' }
    assert last_response.ok?
    assert last_response.body.include?('Unknown User/Password combination, please try again')    
  end

  def test_login_attempt_valid_gives_user_home_screen
    post '/login', {:username => 'root', :password => 'password' }
    assert last_response.ok?
    assert last_response.body.include?('Welcome root.')    
  end

  def test_logout_user_gives_home_screen
# first log in
    post '/login', { :username => 'root', :password => 'password' }
# then log out again
    get '/logout'
    assert last_response.ok?
    assert last_response.body.include?('Please log in again to continue')    
  end

end
