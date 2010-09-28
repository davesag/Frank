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
      haml :'in/index', :locals => { :message => t.u.register_error_already_as(active_username), :user => active_user, :nav_hint => "home" }
    else
      email = params['email']
      name = params['username']
      terms = params['terms']
      if 'true' != terms
    	  haml :register, :locals => { :message => t.u.register_error_terms, :name => name, :email => email, :nav_hint => "register" }        
      else
        if User.username_exists?(name)
      	  haml :register, :locals => { :message => t.u.register_error_username(name), :name => "", :email => email, :nav_hint => "register" }
        elsif User.email_exists?(email)
      	  notify_user_of_registration_overlap_attempt!(email,name)
      	  haml :register, :locals => { :message => t.u.register_error_email(email), :name => name, :email => "", :nav_hint => "register" }
        else
          user = User.create(:username => name, :password => params['password'], :email => email)
          user.set_preference("HTML_EMAIL", "true")
          locale_code = params['locale']
          # just check the locale code provided is legit.
          if !locale_available?(locale_code)
            @@log.error("Unknown local code #{locale_code}supplied.  Check your user interface code.")
            user.locale = R18n::I18n.default
          else
            user.locale = locale_code
            # and set the local
            session[:locale] = locale_code
          end
          user.save!
          send_confirmation_to(user)
          haml :login, :locals => { :message => t.u.register_success(email), :name => name, :nav_hint => "login" }
        end
      end
    end
  end

# checks the user against the validation token.
  get '/validate/:token' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || user.validated?
      haml :index, :locals => { :message => t.u.token_expired_error, :name => "", :nav_hint => "home"}
    else
      user.validated = true
      user.shuffle_token!           # we can't delete a token and they must be unique so we shuffle it after use to prevent reuse.
      user.save!
      haml :login, :locals => { :message => t.u.register_success_confirmed, :name => user.username, :nav_hint => "login" }
    end
  end

end
