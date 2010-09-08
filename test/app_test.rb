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

end
