# shelloworld_test.rb
require 'shelloworld'
require 'test/unit'
require 'rack/test'

class ShelloworldTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_my_default
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('Hello World')
  end

  def test_with_params
    get '/hello/Dave'
    assert last_response.ok?
    assert last_response.body.include?('Hello Dave')
  end
 
end
