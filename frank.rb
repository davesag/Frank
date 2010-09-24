#!usr/bin/ruby

require 'rubygems'
require 'sinatra/base'
require 'active_record'
require 'logger'
require 'pony'
require 'erb'
require 'haml'

class Frank < Sinatra::Base
  enable  :sessions
  set :root, File.dirname(__FILE__)
  set :handlers, Proc.new { root && File.join(root, 'handlers') }
  
  CURRENT_USER_KEY = 'ACTIVE_FRANK_USER'
  LAST_USER_NAME_KEY = 'LAST_KNOWN_FRANK_USERNAME'

  # Externalise all of the various handlers into a /handlers folder
  # each handler will subclass Frank, live in /handlers and be called *_handler.rb
    class << self
      def load_handlers
        if @handlers_are_loaded
          @@log.debug("Handlers were already loaded.")
        else
          raise "No handlers folder" unless File.directory? handlers
          Dir.glob("handlers/**_handler.rb"){ |handler| require handler }
          @@log.debug( "handers loaded" )
          @handlers_are_loaded = true
        end
      end
    end

    configure :development do  
      @@log = Logger.new(STDOUT)
      @@log.level = Logger::DEBUG
      @@log.info("Frank walks onto the stage.")

      ActiveRecord::Base.logger = @@log
      ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database =>  '.FrankData.sqlite3.db'

      @handlers_are_loaded = false
      load_handlers
    end

  # all tempolates within /views/in/ need to use the logged in user template
  # we will also be using Haml to send HTML formatted email but as of this version
  # we will not use mail layout templates.
  helpers do
    def haml(template, options = {}, *)
      if template.to_s.start_with? 'in/'
        options[:layout] ||= :'in/layout'
      elsif template.to_s.start_with? 'mail/'
        options[:layout] ||= false
      end
      super
    end
  end
  
  # some other handy methods
  def login_required! 
    if ! is_logged_in? 
      redirect '/login' 
    end 
  end 

  def is_logged_in?
    session[CURRENT_USER_KEY] != nil
  end

  def log_user_in(user)
    session[CURRENT_USER_KEY] = user
    session[LAST_USER_NAME_KEY] = user.username
  end

  def log_user_out
    if session[CURRENT_USER_KEY] != nil
      # there is a currently logged in user
      session[CURRENT_USER_KEY] = nil
    else
      # nuke the remembered username
      session[LAST_USER_NAME_KEY] = nil
    end
  end

  def nuke_session!
    session[CURRENT_USER_KEY] = nil
    session[LAST_USER_NAME_KEY] = nil
  end

  def active_user
    session[CURRENT_USER_KEY]
  end

  def is_remembered_user?
    session[LAST_USER_NAME_KEY] != nil
  end

  def active_username
    if session[LAST_USER_NAME_KEY] == nil
      return ""
    end
    return session[LAST_USER_NAME_KEY]
  end

  def auth_user(username, password)
    User.login(username, password)
  end
 
# utility method to actually send the email. uses a haml template for HTML email and erb for plain text.
 def send_email_to_user(user, subject, body_template, template_locals)
   if user.get_preference("HTML_EMAIL").value == 'true'
     email_body = haml(body_template, :locals => template_locals )
     type = 'text/html'
   else
     email_body = erb(body_template, :locals => template_locals)
     type = 'text/plain'
   end
   if ENV['RACK_ENV'] != 'test' # TODO: find a cleaner way to achieve this.
     Pony.mail :to => user.email,
               :from => "frank_test@davesag.com",
               :subject => subject,
               :headers => { 'Content-Type' => type },
               :body => email_body
   else
     @@log.debug("TESTING so constructed but did NOT actually send and email to #{user.email} with subject '#{subject}'.")
   end
 end

# notify the user with that email if new registration tries to use your email
  def notify_user_of_registration_overlap_attempt!(email,supplied_name)
    user = User.find_by_email(email)
    template_locals = { :user => user, :supplied_name => supplied_name}
    send_email_to_user(user,"Frank says someone is using your email." ,:'mail/email_warning', template_locals)
  end

# notify the user with that email if user tries to change their email to yours
  def notify_user_of_email_change_overlap_attempt!(email,supplied_name)
    user = User.find_by_email(email)
    template_locals = { :user => user, :supplied_name => supplied_name}
    send_email_to_user(user,"Frank says someone is using your email." ,:'mail/email_change_warning', template_locals)
  end

# generate a confirmation url and email and send it to the user.
  def send_confirmation_to(user)
    token_link = "http://" + request.host_with_port + "/validate/" + user.validation_token
    template_locals = { :user => user, :token_url => token_link}
    send_email_to_user(user,"Frank requests that you verify your email address." ,:'mail/new_registration', template_locals)
  end
  
  def send_email_update_confirmation_to(user)
    token_link = "http://" + request.host_with_port + "/validate/" + user.validation_token
    template_locals = { :user => user, :token_url => token_link}
    send_email_to_user(user,"Frank requests that you verify your email address." ,:'mail/change_email', template_locals)
  end 

  def send_email_password_reset_to(user)
    token_link = "http://" + request.host_with_port + "/reset_password/" + user.validation_token
    template_locals = { :user => user, :token_url => token_link}
    send_email_to_user(user,"You have asked Frank for password assistance." ,:'mail/reset_password', template_locals)
  end 

end
