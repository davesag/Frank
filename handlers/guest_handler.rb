#!usr/bin/ruby

require 'rubygems'
require 'frank'
require 'haml'
require 'active_record'
require 'logger'

require 'models/user'
require 'models/preference'

class GuestHandler < Frank

  # home page - display login form, or divert to user home
  get '/' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => "Welcome", :user => active_user, :nav_tag => "home" }
    else
  	  haml :login, :locals => { :message => "Please log in to continue", :name => active_username, :nav_tag => "login" }
    end
  end

  # login request - display login form, or divert to user home
  get '/login' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => "Welcome back", :user => active_user, :nav_tag => "home" }
    else
  	  haml :login, :locals => { :message => "Please log in to continue", :name => active_username, :nav_tag => "login" }
    end
  end

  #login action - check credentials and load user into session
  post '/login' do
    aName = params['username']
    aPass = params['password']
    aUser = auth_user(aName, aPass)
    if aUser != nil
      log_user_in(aUser)
      haml :'in/index', :locals => { :message => "You have logged in as", :user => aUser, :nav_tag => "home" }
    else
      haml :login, :locals => { :message => "Unknown User/Password combination, please try again",
        :name => active_username, :nav_tag => "login" }
    end
  end
  
  # registration request - display registration form, or divert to user home if logged in
  get '/register' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => "You are already logged in as", :user => active_user, :nav_tag => "home" }
    elsif is_remembered_user?
      haml :login, :locals => { :message => "Please logout completely before trying to register a new user.",
         :name => active_username, :nav_tag => "login" }
	  else
  	  haml :register, :locals => { :message => "Registration is fast and free", :name => "", :nav_tag => "register" }
    end
  end

end
