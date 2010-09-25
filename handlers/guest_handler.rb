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
      haml :'in/index', :locals => { :message => t.u.welcome_in, :user => active_user, :nav_tag => "home" }
    else
  	  haml :login, :locals => { :message => t.u.login_message, :name => active_username, :nav_tag => "login" }
    end
  end

  # privacy page - display privacy text
  get '/privacy' do
    if is_logged_in?
      haml :'privacy', :locals => { :message => t.u.privacy_title_in, :user => active_user, :nav_tag => "privacy" }
    else
  	  haml :privacy, :locals => { :message => t.u.privacy_title_out, :name => active_username, :nav_tag => "privacy" }
    end
  end

  # privacy page - display privacy text
  get '/terms' do
    if is_logged_in?
      haml :'terms', :locals => { :message => t.u.terms_title_in, :user => active_user, :nav_tag => "terms" }
    else
  	  haml :terms, :locals => { :message => t.u.terms_title_out, :name => active_username, :nav_tag => "terms" }
    end
  end

  # login request - display login form, or divert to user home
  get '/login' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.welcome_in, :user => active_user, :nav_tag => "home" }
    else
  	  haml :login, :locals => { :message => t.u.login_message, :name => active_username, :nav_tag => "login" }
    end
  end

  #login action - check credentials and load user into session
  post '/login' do
    aName = params['username']
    aPass = params['password']
    aUser = auth_user(aName, aPass)
    if aUser != nil
      log_user_in(aUser)
      haml :'in/index', :locals => { :message => t.u.login_success, :user => aUser, :nav_tag => "home" }
    else
      haml :login, :locals => { :message => t.u.login_error, :name => active_username, :nav_tag => "login" }
    end
  end
  
  # registration request - display registration form, or divert to user home if logged in
  get '/register' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.register_error_already_as(active_username), :user => active_user, :nav_tag => "home" }
    elsif is_remembered_user?
      haml :login, :locals => { :message => t.u.register_error,
         :name => active_username, :nav_tag => "login" }
	  else
  	  haml :register, :locals => { :message => t.u.register_message, :name => "", :email => "", :nav_tag => "register" }
    end
  end

  # registration request - display registration form, or divert to user home if logged in
  get '/forgot_password' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.forgot_password_error_already_as(active_username), :user => active_user, :nav_tag => "home" }
	  else
  	  haml :forgot_password, :locals => { :message => t.u.forgot_password, :name => active_username, :nav_tag => "forgot_password" }
    end
  end

  post '/forgot_password' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.forgot_password_error_already_as(active_username), :user => active_user, :nav_tag => "home" }
	  else
	    user = User.find_by_email(params[:email])
	    if user == nil
        haml :forgot_password, :locals => { :message => t.u.forgot_password_error, :name => active_username, :nav_tag => "forgot_password" }	      
      else
        user.password_reset = true
        user.save!
        send_password_reset_to(user)
    	  haml :message_only, :locals => { :message => t.u.forgot_password_instruction,
    	    :detailed_message => t.u.forgot_password_instruction_detailed, 
    	    :name => user.username, :nav_tag => "forgot_password" }
      end
    end
    
  end

  get '/reset_password/:token' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || !user.password_reset?
      haml :login, :locals => { :message => t.u.token_expired_error, :name => "", :nav_tag => "login"}
    else
      haml :reset_password, :locals => { :message => t.u.forgot_password_instruction_email,
          :name => user.username, :validation_token => user.validation_token, :nav_tag => "forgot_password" }
    end
  end

  post '/reset_password' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || !user.password_reset?
      haml :login, :locals => { :message => t.u.token_expired_error, :name => "", :nav_tag => "login"}
    else
      # actually change the password
      user.password = params[:password]
      user.password_reset = false
      user.save!
      nuke_session!
      haml :login, :locals => { :message => t.u.forgot_password_success, :name => user.username, :nav_tag => "login" }
    end
  end
end
