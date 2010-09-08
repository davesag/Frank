#!usr/bin/ruby

require 'rubygems'
require 'sinatra'
require 'haml'
require 'active_record'
require 'logger'

require 'models/user'

enable :sessions

CURRENT_USER_KEY = 'ACTIVE_TEST_APP_USER'

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database =>  '.FrankData.sqlite3.db'
ActiveRecord::Base.logger = Logger.new(STDOUT)

def is_logged_in?
  session[CURRENT_USER_KEY] != nil
end

def log_user_in(user)
  session[CURRENT_USER_KEY] = user
end

def log_user_out
  session[CURRENT_USER_KEY] = nil
end

def active_user
  session[CURRENT_USER_KEY]
end

def auth_user(username, password)
  User.find(:first, :conditions => { :username => username, :password => password })
end

get '/' do
  if is_logged_in?
    haml :'in/index', :locals => { :user => active_user }
  else
	  haml :login, :locals => { :message => "Please log in to continue." }
  end
end

get '/login' do
  if is_logged_in?
    haml :'in/index', :locals => { :user => active_user }
  else
	  haml :login, :locals => { :message => "Please log in to continue." }
  end
end

get '/logout' do
  if is_logged_in?
    name = active_user.username
    log_user_out
    haml :login, :locals => { :message => "Thanks for visiting #{name}. Please log in again to continue." }
  else
    haml :login, :locals => { :message => "You were not logged in. Please log in to continue." }
  end
end

post '/login' do
  aName = params['username']
  aPass = params['password']
  aUser = auth_user(aName, aPass)
  if aUser != nil
    log_user_in(aUser)
    haml :'in/index', :locals => { :user => aUser }
  else
    haml :login, :locals => { :message => "Unknown User/Password combination, please try again." }
  end
end
