ENV['RACK_ENV'] = "development"

require "frank"

run Sinatra::Application
