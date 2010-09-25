#!usr/bin/ruby

require 'rubygems'
require 'frank'
require 'haml'
require 'active_record'
require 'logger'

require 'models/user'
require 'models/preference'

class RegistrationHandler < Frank

# registration action - check username and email are unique and valid and display 'check your email' page
  post '/registration' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.register_error_already_as(active_username), :user => active_user, :nav_tag => "home" }
    else
      anEmail = params['email']
      aName = params['username']
      aPass = params['password']
      terms = params['terms']
      if terms == 'false'
    	  haml :register, :locals => { :message => t.u.register_error_terms, :name => aName, :email => anEmail, :nav_tag => "register" }        
      else
        if User.username_exists?(aName)
      	  haml :register, :locals => { :message => t.u.register_error_username(aName), :name => "", :email => anEmail, :nav_tag => "register" }
        elsif User.email_exists?(anEmail)
      	  notify_user_of_registration_overlap_attempt!(anEmail,aName)
      	  haml :register, :locals => { :message => t.u.register_error_email(anEmail), :name => aName, :email => "", :nav_tag => "register" }
        else
          user = User.create(:username => aName, :password => aPass, :email => anEmail)
          user.set_preference("HTML_EMAIL", "true")
          user.save!
          send_confirmation_to(user)
          haml :login, :locals => { :message => t.u.register_success(anEmail), :name => "#{aName}", :nav_tag => "login" }
        end
      end
    end
  end

# checks the user against the validation token.
  get '/validate/:token' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || user.validated?
      haml :index, :locals => { :message => t.u.token_expired_error, :name => "", :nav_tag => "home"}
    else
      user.validated = true
      user.save!
      haml :login, :locals => { :message => t.u.register_success_confirmed, :name => user.username, :nav_tag => "login" }
    end
  end

end
