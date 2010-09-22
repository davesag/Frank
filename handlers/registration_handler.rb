#!usr/bin/ruby

require 'rubygems'
require 'frank'
require 'haml'
require 'active_record'
require 'logger'

require 'models/user'
require 'models/preference'

class RegistrationHandler < Frank

  #registration action - check username and email are unique and valid and display 'check your email' page
  post '/registration' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => "You are already logged in as", :user => active_user }
    else
      anEmail = params['email']
      aName = params['username']
      aPass = params['password']
      if User.username_exists?(aName)
    	  haml :register, :locals => { :message => "A user with username '#{aName}' already exists", :name => "" }
      elsif User.email_exists?(anEmail)
    	  haml :register, :locals => { :message => "A user with email '#{anEmail}' already exists", :name => aName }
    	  # TODO: notify the user with that email
      else
        user = User.create(:username => aName, :password => aPass, :email => anEmail)
        user.set_preference("HTML_EMAIL", "true")
        user.save!
        #TODO: generate a confirmation email and url and send it to the user.
        haml :login, :locals => { :message => "A confirmation email has been sent to #{anEmail}. You will not be able to log in until you confirm your email address.", :name => "#{aName}" }
      end
    end
  end
end
