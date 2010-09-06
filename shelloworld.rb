# shelloworld.rb
require 'rubygems'
require 'sinatra'
require 'haml'

aDefaultMessage = "Hello"

get '/' do
	haml :index, :locals => { :name => "World", :message => aDefaultMessage}
end

get '/hello/:name' do
  aName = params[:name]
	haml :index, :locals => { :name => aName, :message => aDefaultMessage }
end

get '/login' do
	haml :login, :locals => { :message => 'Please log in' }
end

post '/' do
  aName = params['username']
  if aName == 'Dave'
    haml :index, :locals => { :name => aName, :message => "Welcome" }
  else
    haml :login, :locals => { :message => "Unknown User '#{aName}', please try again" }
  end
end
