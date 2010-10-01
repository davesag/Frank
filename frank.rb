#!usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
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
  
  ACTIVE_USER_NAME_KEY = 'ACTIVE_FRANK_USERNAME'
  REMEMBERED_USER_NAME_KEY = 'LAST_KNOWN_FRANK_USERNAME'

  @active_user = nil         # the active user is reloaded on each request in the before method.

  # Externalise all of the various handlers into a /handlers folder
  # each handler will subclass Frank, live in /handlers and be called *_handler.rb
  class << self
    def load_handlers
      if !@handlers_are_loaded
        raise "No handlers folder" unless File.directory? handlers
        Dir.glob("handlers/**_handler.rb"){ |handler| require handler }
        @@log.debug( "handers loaded" )
        @handlers_are_loaded = true
      end
    end
  end

  # configuration blocks are called depending on the value of ENV['RACK_ENV] #=> 'test', 'development', or 'production'
  # on Heroku the default rack environment is 'production'.  Locally it's development.
  # if you switch rack environments locally you will need to reseed the database as it uses different databases for each obviously.
  configure :development do
    set :environment, :development
    @@log = Logger.new(STDOUT)
    @@log.level = Logger::DEBUG
    @@log.info("Frank walks onto the stage to rehearse.")

    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger.level = Logger::INFO      #not interested in database stuff right now.

    dbconfig = YAML.load(File.read('config/database.yml'))
    ActiveRecord::Base.establish_connection dbconfig['development']

    @handlers_are_loaded = false
    load_handlers
  end

  configure :production do  
    set :environment, :production
    @@log = Logger.new(STDOUT)  # TODO: should look for a better option than this.
    @@log.level = Logger::DEBUG
    @@log.info("Frank walks onto the stage to perform.")

    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger.level = Logger::WARN

    dbconfig = YAML.load(File.read('config/database.yml'))
    ActiveRecord::Base.establish_connection dbconfig['production']

    @handlers_are_loaded = false
    load_handlers
  end

  configure :test do  
    set :environment, :test
    @@log = Logger.new(STDOUT)
    @@log.level = Logger::DEBUG
    @@log.info("Frank clears his throat and does his scales in front of the mirror.")

    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger.level = Logger::WARN      #not interested in database stuff right now.

    dbconfig = YAML.load(File.read('config/database.yml'))
    ActiveRecord::Base.establish_connection dbconfig['test']

    @handlers_are_loaded = false
    load_handlers
  end

  # if there is a new locale setting in the request then use it.
  before do
    session[:locale] = params[:locale] if params[:locale] #the r18n system will load it automatically

    refresh_active_user!

  end

  # we use haml to create HTML rendered email, in which case we need to avoid using the web-facing templates
  # if the user is logged in then use /in/layout.haml as a layout template.
  # all templates within /views/in/ need to use their local (ie /in/layout.haml) layout template.
  # if it's not a chunk template then change the template path depending on avaialable locales.
  # however templates in the 'views/chunks' folder are just chunks and are only to be injected into other haml templates, so use no layout
  # TODO: as we add SaaS functions and REST interfaces we'll want to use other templates too, so edit here when the time comes.
  helpers do
    def haml(template, options = {}, *)
      
      # template will either be the name of a template or the body of a template.
      # if it's the body then it will contain a "%" symbol and so we can skip any processing
      
      template_name = template.to_s
      do_not_localise = false
      if template_name.include?('%')
#        @@log.debug("haml: Aboout to render a chunk of haml content")
        # it's actually the template content we have here, not a template name
        super
      else
#        @@log.debug("haml: Aboout to render an haml template called #{template_name}")
        # it's a template name we have here.
        # note layout.haml files must never hold untranslated text
        if template_name.include?('chunks/')
          options[:layout] ||= false
          do_not_localise = true
#          @@log.debug("haml: It's a chunk so don't attempt to localise and don't use a layout.")
        elsif template_name.include?('mail/')
          options[:layout] ||= false
#          @@log.debug("haml: It's an email so don't use a layout.")
        elsif is_logged_in? || template_name.include?('in/')
          options[:layout] ||= :'in/layout'
#          @@log.debug("haml: Use the logged in layout.")
        end

        # now if template_bits[0] is a locale code then just pass through
        if do_not_localise
          # "Don't bother localising chunks.
#          @@log.debug("haml: Nothing to localise so proceed as normal.")
          super
        else
          # there is no locale code in front of the template name
          # now make an adjustment to the template path depending on locale.
          local_template_file = "views/#{r18n.locale.code.downcase}/#{template_name}.haml"
          if File.exists? local_template_file
            # Found a localised template so we'll use that one
            local_template = File.read(local_template_file)
#            @@log.debug("haml: found #{local_template_file} so will recurse and load that.")
            return haml(local_template, options)
          elsif r18n.locale.sublocales != nil && r18n.locale.sublocales.size > 0
            # Couldn't find a template for that specific locale.
#            @@log.debug("haml: could not find anything called #{local_template_file} so will dig deeper.")
            local_template_file = "views/#{r18n.locale.sublocales[0].downcase}/#{template_name}.haml"
            if File.exists? local_template_file
              # but there is a more generic language file so use that.
              # note if I really wanted to I could loop through in case sublocales[0] doesn't exist but other one does.
              # too complicated for now though and simply not needed.  TODO: polish this up later.
              local_template = File.read(local_template_file)
#              @@log.debug("haml: Found a more generic translation in #{local_template_file} so will recurse and use that.")
              return haml(local_template, options)
            else
              # No localsied version of this template exists. Okay use the template we were supplied.
#              @@log.debug("haml: No localised versions of that template exist so use #{template_name}")
              super
            end
          else
            # That locale has no sublocales so just use the template we were supplied.
#            @@log.debug("haml: That's as deep as we can look for a localised file.  Using #{template_name}")
            super
          end
        end
      end
    end

    # we use erb to create plain text rendered email and
    # change the template path depending on the active locale.
    def erb(template, options = {}, *)
      # template will either be the name of a template or the body of a template.
      # if it's the body then it will contain a "%" symbol and so we can skip any processing
      
      template_name = template.to_s
      
      if template_name.include?('%')
        # it's actually the template content we have here, not a template name
        super
      else
        # it's a template name we have here.

        # now make an adjustment to the template path depending on locale.
        local_template_file = "views/#{r18n.locale.code.downcase}/#{template_name}.erb"
        if File.exists? local_template_file
          # Found a localised template so we'll use that one
          local_template = File.read(local_template_file)
          return erb(local_template, options)
        elsif r18n.locale.sublocales != nil && r18n.locale.sublocales.size > 0
          # Couldn't find a template for that specific locale.
          local_template_file = "views/#{r18n.locale.sublocales[0].downcase}/#{template_name}.erb"
          if File.exists? local_template_file
            # but there is a more generic language file so use that.
            # note if I really wanted to I could loop through in case sublocales[0] doesn't exist but other one does.
            # too complicated for now though and simply not needed.  TODO: polish this up later.
            local_template = File.read(local_template_file)
            return erb(local_template, options)
          else
            # No localsied version of this template exists. Okay use the template we were supplied.
            super
          end
        else
          # That locale has no sublocales so just use the template we were supplied.
          super
        end
      end
    end
  end
  
  #################       LOGGING IN AND OUT AND SO FORTH     ###########################
  
  # bounces the user to the login page if they are not logged in.
  def login_required! 
    if ! is_logged_in? 
      redirect '/login' 
    end 
  end 

  # bounces the user to the login page if they are not logged in,
  # and to whichever path is supplied as a bounce path
  # if they are logged in but not an Admin.
  def admin_required!(bounce)
    if !is_logged_in? 
      redirect '/login' 
    end
    if !active_user.has_role?('admin')
      redirect bounce
    end
  end 

  # ther user is logged in IF the @active_user != nil.
  def is_logged_in?
    @active_user != nil
  end

  # load the valid user with the supplied username into the @active_user instance attribute.
  def log_user_in!(user)
    if user == nil
      @@log.error("Call to log_user_in!(nil).  This should never be th case.  Please check your handlers.")
    else
      @active_user = user
      session[ACTIVE_USER_NAME_KEY] = user.username
      session[REMEMBERED_USER_NAME_KEY] = user.username
      if @active_user.locale != nil
        session[:locale] = @active_user.locale
      end
      @@log.info("Logged in user called '#{user.username}'")
    end
  end

  # load the valid user with the supplied username into the @active_user instance attribute.
  def log_username_in(username)
    @active_user = User.find_by_username_and_validated(username, true)
    if @active_user == nil
      @@log.error("Call to log_username_in(#{username}) failed as either there was no user with that name, or that user was not validated and so can't log in.")
    else
      @@log.debug("Logged in user called '#{username}'")
      session[ACTIVE_USER_NAME_KEY] = username
      session[REMEMBERED_USER_NAME_KEY] = username
      if @active_user.locale != nil
        session[:locale] = @active_user.locale
      end
    end
  end

  def refresh_active_user!
    if session[ACTIVE_USER_NAME_KEY] != nil
      # there is a currently logged in user so load her up
      @active_user = User.find_by_username(session[ACTIVE_USER_NAME_KEY])
      if @active_user.locale != nil
        session[:locale] = @active_user.locale
      end
      @@log.info("Refreshed user #{@active_user.username}")
    end
  end

  # if there is an active user then nil the @active_user and the session[ACTIVE_USER_NAME_KEY]
  # else nil session[REMEMBERED_USER_NAME_KEY]
  def log_user_out
    if session[ACTIVE_USER_NAME_KEY] != nil
      # there is a currently logged in user
      session[ACTIVE_USER_NAME_KEY] = nil
      @active_user = nil
    else  #there is no active user, ie logout has been called before.
      # nuke the remembered username
      session[REMEMBERED_USER_NAME_KEY] = nil
    end
  end

  def nuke_session!
    @@log.warn("You should really avoid calling nuke_session!")
    session[ACTIVE_USER_NAME_KEY] = nil
    session[REMEMBERED_USER_NAME_KEY] = nil
  end

  def active_user
    return @active_user
  end

  def is_remembered_user?
    session[REMEMBERED_USER_NAME_KEY] != nil
  end

  def active_user_name
    if session[ACTIVE_USER_NAME_KEY] == nil
      return ""
    end
    return session[ACTIVE_USER_NAME_KEY]
  end

  def remember_user_name(username)
    session[REMEMBERED_USER_NAME_KEY] = username
  end

  def remembered_user_name
    if session[REMEMBERED_USER_NAME_KEY] == nil
      return ""
    end
    return session[REMEMBERED_USER_NAME_KEY]
  end

  def auth_user(username, password)
    return User.login(username, password)
  end
 
  def locale_available?(locale_code)
    r18n.available_locales.each do |locl|
      return true if locale_code == locl.code
    end
    return false
  end
 
  def is_blessed_role?(role)
    return ['admin', 'superuser'].include?(role.name)
  end
 
  #################       UTILITY METHODS FOR SENDING USER EMAILS     ###########################
 
# utility method to actually send the email. uses a haml template for HTML email and erb for plain text.
  def send_email_to_user(user, subject, body_template, template_locals)   
    if 'true' == user.get_preference("HTML_EMAIL").value
      email_body = haml(body_template, :locals => template_locals )
      type = 'text/html'
    else
      email_body = erb(body_template, :locals => template_locals)
      type = 'text/plain'
    end
    
    if options.environment == :development                          # assumed to be on your local machine
      Pony.mail :to => user.email, :via =>:sendmail,
        :from => "frank_test@davesag.com", :subject => subject,
        :headers => { 'Content-Type' => type }, :body => email_body
      @@log.debug("Email sent via SendMail in local Developer environment.")
    elsif options.environment == :production                         # assumed to be Heroku
      Pony.mail :to => user.email, :from => "frank_demo@davesag.com", :subject => subject,
        :headers => { 'Content-Type' => type }, :body => email_body, :via => :smtp,
        :via_options => {
          :address => 'smtp.sendgrid.net',
          :port => 25,
          :authentication => :plain,
          :user_name => ENV['SENDGRID_USERNAME'],
          :password => ENV['SENDGRID_PASSWORD'],
          :domain => ENV['SENDGRID_DOMAIN'] }
        @@log.debug("Email sent via SMTP in production environment on Heroku.")
    else
      @@log.debug("TESTING so I constructed, but did NOT actually send, an email to #{user.email} with subject '#{subject}' using template '#{body_template}'.")
    end
  end

# notify the user with that email if new registration tries to use your email
  def notify_user_of_registration_overlap_attempt!(email,supplied_name)
    user = User.find_by_email(email)
    template_locals = { :user => user, :supplied_name => supplied_name}
    send_email_to_user(user, t.u.mail_registration_email_overlap_subject, :'mail/email_warning', template_locals)
  end

# notify the user with that email if user tries to change their email to yours
  def notify_user_of_email_change_overlap_attempt!(email,supplied_name)
    user = User.find_by_email(email)
    template_locals = { :user => user, :supplied_name => supplied_name}
    send_email_to_user(user, t.u.mail_edit_email_overlap_subject, :'mail/email_change_warning', template_locals)
  end

# generate a confirmation url and email and send it to the user.
  def send_registration_confirmation_to(user)
    token_link = "http://" + request.host_with_port + "/validate/" + user.validation_token
    template_locals = { :user => user, :token_url => token_link}
    send_email_to_user(user, t.u.mail_registration_confirmation_subject, :'mail/new_registration', template_locals)
  end
  
  def send_email_update_confirmation_to(user)
    token_link = "http://" + request.host_with_port + "/validate/" + user.validation_token
    template_locals = { :user => user, :token_url => token_link}
    send_email_to_user(user, t.u.mail_edit_email_confirmation_subject, :'mail/change_email', template_locals)
  end

  def send_password_reset_to(user)
    token_link = "http://" + request.host_with_port + "/reset_password/" + user.validation_token
    template_locals = { :user => user, :token_url => token_link}
    send_email_to_user(user, t.u.mail_password_reset_subject, :'mail/reset_password', template_locals)
  end 

end
