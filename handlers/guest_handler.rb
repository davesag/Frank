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
      haml :'in/index', :locals => { :message => "Welcome", :user => active_user }
    else
  	  haml :login, :locals => { :message => "Please log in to continue", :name => "" }
    end
  end

  # login request - display login form, or divert to user home
  get '/login' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => "Welcome back", :user => active_user }
    else
  	  haml :login, :locals => { :message => "Please log in to continue", :name => "" }
    end
  end

  # registration request - display registration form, or divert to user home if logged in
  get '/register' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => "You are already logged in as", :user => active_user }
    else
  	  haml :register, :locals => { :message => "Registration is fast and free", :name => "" }
    end
  end

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
