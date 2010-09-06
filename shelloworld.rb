# shelloworld.rb
require 'rubygems'
require 'sinatra'
require 'haml'

get '/' do
	haml :index, :locals => { :name => "World"}
end

get '/hello/:name' do
  aName = params[:name]
	haml :index, :locals => { :name => aName }
end
