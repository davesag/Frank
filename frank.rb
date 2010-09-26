#!usr/bin/ruby

require 'rubygems'
require 'sinatra/base'
require 'sinatra/r18n'
require 'active_record'
require 'logger'
require 'pony'
require 'erb'
require 'haml'

class Frank < Sinatra::Base
  enable  :sessions
  set :root, File.dirname(__FILE__)
  set :handlers, Proc.new { root && File.join(root, 'handlers') }
  register Sinatra::R18n
  
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

  # TODO: someone needs to work out how these work.
  # I tried setting up a configure :test block but it was never called.
  configure :development do  
    @@log = Logger.new(STDOUT)
    @@log.level = Logger::DEBUG
    @@log.info("Frank walks onto the stage.")

    ActiveRecord::Base.logger = @@log
    ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database =>  '.FrankData.sqlite3.db'

    @handlers_are_loaded = false
    load_handlers
  end

  # if there is a new locale setting in the request then use it.
  before do
    session[:locale] = params[:locale] if params[:locale] #the r18n system will load it automatically

    # expected behaviour
    # default local is English. 'en'
    # Also installed are Australian English (not recognised by R18n), British English and French.
    # by appending ?locale=fr for example you can switch the language to French.
    # you should also be able to switch between British English, Australian English and a terser default English but the AU and GB dialects don't load
    # I have filed an issue with the R18n people.
    # See notes in http://davesag.lighthouseapp.com/projects/59602-frank/tickets/17-add-internationalisation-i18n-and-localisation-suppport

    @@log.debug("Locale is '#{r18n.locale.code}' (#{r18n.locale.title})")   # show that the Locale is being set as expected.
    @@log.debug("Default Locale is '#{R18n::I18n.default}'")                # note the default code
                                                                            # step through all of the 'available' locales.
    r18n.available_locales.each do |locl|                                   # available means there is a {locale.code}.yml file in ROOT/i18n/
      default = R18n::I18n.default == locl.code ? ": Default" : ""          # is this the default locale? (in case the one we choose is unavailable).
      star = r18n.locale == locl ? " <== active" : ""                       # active means this is the locale we are currently using.
      supp = locl.supported? ? " and is supported   " : " but isn't supported" # supported means R18n::Locale.exists?(locl.code) == true
      @@log.debug("Available#{supp}: '#{locl.code}' (#{locl.title})#{default}#{star}")
    end
  end

  # we use haml to create HTML rendered email, in which case we need to avoid using the web-facing templates
  # if the user is logged in then use /in/layout.haml as a layout template.
  # all templates within /views/in/ need to use their local (ie /in/layout.haml) layout template.
  # TODO: as we add SaaS functions and REST interfaces we'll want to use other templates too, so edit here when the time comes.
  helpers do
    def haml(template, options = {}, *)
      if template.to_s.start_with? 'mail/'
        options[:layout] ||= false
      elsif is_logged_in? || template.to_s.start_with?('in/')
        options[:layout] ||= :'in/layout'
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
     @@log.info("TESTING so I constructed, but did NOT actually send, an email to #{user.email} with subject '#{subject}' using template '#{body_template}'.")
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

  def send_password_reset_to(user)
    token_link = "http://" + request.host_with_port + "/reset_password/" + user.validation_token
    template_locals = { :user => user, :token_url => token_link}
    send_email_to_user(user,"You have asked Frank for password assistance." ,:'mail/reset_password', template_locals)
  end 

end
