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

  # registration request - display registration form, or divert to user home if logged in
  get '/forgot_password' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => "You are already logged in as", :user => active_user, :nav_tag => "home" }
	  else
  	  haml :forgot_password, :locals => { :message => "Please provide your email address and we will reset your password", 
  	    :name => "", :nav_tag => "forgot_password" }
    end
  end

  post '/forgot_password' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => "You are already logged in as", :user => active_user, :nav_tag => "home" }
	  else
	    user = User.find_by_email(params[:email])
	    if user == nil
        haml :forgot_password, :locals => { :message => "I'm sorry but that email address is unknown to me, please try another one.",
          :name => active_username, :nav_tag => "forgot_password" }	      
      else
        user.password_reset = true
        user.save!
        send_email_password_reset_to(user)
    	  haml :message_only, :locals => { :message => "Please check your email for your password reset instructions.",
    	    :detailed_message => "An email with a password reset link has been sent to your email address.", 
    	    :name => user.username, :nav_tag => "forgot_password" }
      end
    end
    
  end

  get '/reset_password/:token' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || !user.password_reset?
      haml :login, :locals => { :message => "That token has expired and so did not match any known users.", :name => "", :nav_tag => "login"}
    else
      haml :reset_password, :locals => { :message => "Please supply a new password.",
          :name => user.username, :validation_token => user.validation_token, :nav_tag => "forgot_password" }
    end
  end

  post '/reset_password' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || !user.password_reset?
      haml :login, :locals => { :message => "That token has expired and so did not match any known users.", :name => "", :nav_tag => "login"}
    else
      # actually change the password
      user.password = params[:password]
      user.password_reset = false
      user.save!
      nuke_session!
      haml :login, :locals => { :message => "Your password has been reset. Please log in.", :name => user.username, :nav_tag => "login" }
    end
  end
end
