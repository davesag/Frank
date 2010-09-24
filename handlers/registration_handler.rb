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
      haml :'in/index', :locals => { :message => "You are already logged in as", :user => active_user, :nav_tag => "home" }
    else
      anEmail = params['email']
      aName = params['username']
      aPass = params['password']
      if User.username_exists?(aName)
    	  haml :register, :locals => { :message => "A user with username '#{aName}' already exists", :name => "", :nav_tag => "register" }
      elsif User.email_exists?(anEmail)
    	  notify_user_of_registration_overlap_attempt!(anEmail,aName)
    	  haml :register, :locals => { :message => "A user with email '#{anEmail}' already exists", :name => aName, :nav_tag => "register" }
      else
        user = User.create(:username => aName, :password => aPass, :email => anEmail)
        user.set_preference("HTML_EMAIL", "true")
        user.save!
        send_confirmation_to(user)
        haml :login,
          :locals => { :message => "A confirmation email has been sent to #{anEmail}. You will not be able to log in until you confirm your email address.", 
          :name => "#{aName}", :nav_tag => "login" }
      end
    end
  end

# checks the user against the validation token.
  get '/validate/:token' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || user.validated?
      haml :index, :locals => { :message => "That token has expired and so did not match any known users.", :name => "", :nav_tag => "home"}
    else
      user.validated = true
      user.save!
      haml :login, :locals => { :message => "Your registration has been confirmed. You may now log in.", :name => user.username, :nav_tag => "login" }
    end
  end

end
