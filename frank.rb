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
  set :models, Proc.new { root && File.join(root, 'models') }
  register Sinatra::R18n
  
  ACTIVE_USER_NAME_KEY = 'ACTIVE_FRANK_USERNAME'
  REMEMBERED_USER_NAME_KEY = 'LAST_KNOWN_FRANK_USERNAME'

  @active_user = nil         # the active user is reloaded on each request in the before method.

  # No longer externalise all of the various handlers into a /handlers folder
  # aas thi smodel was breaking when hosted on Heroku
  # TODO: find a better way to achieve the splitting up of handlers.
#  class << self
#    def load_handlers
#      if !@models_are_loaded
#        raise "No handlers folder" unless File.directory? handlers
#        Dir.glob("handlers/**_handler.rb"){ |handler| require handler }
#        @@log.debug( "handers loaded" )
#        @models_are_loaded = true
#      end
#    end
#  end

  class << self
    def load_models
      if !@models_loaded
        raise "No models folder found!" unless File.directory? models
        Dir.glob("models/**.rb") { |m| require m }
        @@log.debug("Models loaded")
        @models_are_loaded = true
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

    @models_are_loaded = false
    load_models
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

    @models_are_loaded = false
    load_models
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

    @models_are_loaded = false
    load_models
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
      @@log.error("Call to log_user_in!(nil).  This should never be the case.  Please check your route handlers in frank.rb.")
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
      @@log.info("Loaded user #{@active_user.username}")
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

######################   GUEST HANDLERS   #################################

  get '/testing' do
    if is_logged_in?
      haml :'testing', :locals => { :message => "Testing POST as logged in User", :user => active_user, :nav_hint => "home" }
    else
  	  haml :testing, :locals => { :message =>"Testing POST as guest", :name => remembered_user_name, :nav_hint => "login" }
    end
  end

  post '/testing' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => "Testing POST as logged in User", :user => active_user, :nav_hint => "home" }
    else
  	  haml :login, :locals => { :message =>"Testing POST as guest", :name => remembered_user_name, :nav_hint => "login" }
    end
  end

  # home page - display login form, or divert to user home
  get '/' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.welcome_in, :user => active_user, :nav_hint => "home" }
    else
  	  haml :login, :locals => { :message => t.u.login_message, :name => remembered_user_name, :nav_hint => "login" }
    end
  end

  # privacy page - display privacy text
  get '/privacy' do
    if is_logged_in?
      haml :'privacy', :locals => { :message => t.u.privacy_title_in, :user => active_user, :nav_hint => "privacy" }
    else
  	  haml :privacy, :locals => { :message => t.u.privacy_title_out, :name => remembered_user_name, :nav_hint => "privacy" }
    end
  end

  # privacy page - display privacy text
  get '/terms' do
    if is_logged_in?
      haml :'terms', :locals => { :message => t.u.terms_title_in, :user => active_user, :nav_hint => "terms" }
    else
  	  haml :terms, :locals => { :message => t.u.terms_title_out, :name => remembered_user_name, :nav_hint => "terms" }
    end
  end

  # login request - display login form, or divert to user home
  get '/login' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.welcome_in, :user => active_user, :nav_hint => "home" }
    else
  	  haml :login, :locals => { :message => t.u.login_message, :name => remembered_user_name, :nav_hint => "login" }
    end
  end

  #login action - check credentials and load user into session
  post '/login' do
    name = params['username']
    pass = params['password']
    entering_user = auth_user(name, pass)
    if entering_user != nil
      log_user_in!(entering_user)
      haml :'in/index', :locals => { :message => t.u.login_success, :user => active_user, :nav_hint => "home" }
    else
      haml :login, :locals => { :message => t.u.login_error, :name => remembered_user_name, :nav_hint => "login" }
    end
  end

  # registration request - display registration form, or divert to user home if logged in
  get '/register' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.register_error_already_as(active_user_name), :user => active_user, :nav_hint => "home" }
    elsif is_remembered_user?
      haml :login, :locals => { :message => t.u.register_error,
         :name => remembered_user_name, :nav_hint => "login" }
	  else
  	  haml :register, :locals => { :message => t.u.register_message, :name => "", :email => "", :nav_hint => "register" }
    end
  end

  # registration request - display registration form, or divert to user home if logged in
  get '/forgot_password' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.forgot_password_error_already_as(active_user_name), :user => active_user, :nav_hint => "home" }
	  else
  	  haml :forgot_password, :locals => { :message => t.u.forgot_password, :name => remembered_user_name, :nav_hint => "forgot_password" }
    end
  end

  post '/forgot_password' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.forgot_password_error_already_as(active_user_name), :user => active_user, :nav_hint => "home" }
	  else
	    user = User.find_by_email(params[:email])
	    if user == nil
        haml :forgot_password, :locals => { :message => t.u.forgot_password_error, :name => remembered_user_name, :nav_hint => "forgot_password" }	      
      else
        user.password_reset = true
        user.save!
        send_password_reset_to(user)
    	  haml :message_only, :locals => { :message => t.u.forgot_password_instruction,
    	    :detailed_message => t.u.forgot_password_instruction_detail, 
    	    :name => user.username, :nav_hint => "forgot_password" }
      end
    end
    
  end

  get '/reset_password/:token' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || !user.password_reset?
      haml :login, :locals => { :message => t.u.token_expired_error, :name => "", :nav_hint => "login"}
    else
      haml :reset_password, :locals => { :message => t.u.forgot_password_instruction_email,
          :name => user.username, :validation_token => user.validation_token, :nav_hint => "forgot_password" }
    end
  end

  post '/reset_password' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || !user.password_reset?
      haml :login, :locals => { :message => t.u.token_expired_error, :name => "", :nav_hint => "login"}
    else
      # actually change the password (note this is stored as a bcrypted string, not in clear text)
      user.password = params[:password]
      user.password_reset = false   # this is a secuity measure to prevent  someone with a matching token resetting a
                                    # password that was not requested to be reset.
      user.shuffle_token!           # we can't delete a token and they must be unique so we shuffle it after use.
      user.save!
#      nuke_session!
      remember_user_name(user.username)
      haml :login, :locals => { :message => t.u.forgot_password_success, :name => remembered_user_name, :nav_hint => "login" }
    end
  end

######################  REGISTRATION HANDLERS #############################

  # registration action - check username and email are unique and valid and display 'check your email' page
  post '/registration' do
    if is_logged_in?
      haml :'in/index', :locals => { :message => t.u.register_error_already_as(active_user_name), :user => active_user, :nav_hint => "home" }
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
          locale_code = params[:locale]
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
          send_registration_confirmation_to(user)
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

##########################  USER HANDLERS   ###############################

  #logout action  - nuke user from session, display login form and thank user
  get '/logout' do
    if is_logged_in?
      name = active_user_name
      log_user_out
      haml :login, :locals => { :message => t.u.logout_message(name), :name => "#{name}", :nav_hint => "login" }
    elsif is_remembered_user?
      name = remembered_user_name
      log_user_out
      haml :login, :locals => { :message => t.u.logout_completely(name), :name => "", :nav_hint => "login" }
    else
      haml :login, :locals => { :message => t.u.logout_error, :name => "", :nav_hint => "login" }
    end
  end

  # a user can delete themselves.
  post '/delete_self' do    
    if is_logged_in?
      if active_user.has_role?('admin')
        @@log.error("/delete_self called by an admin. Admin's can't delete themselves. Check the UI and Navigation options in your templates.")
        # admin users can not delete themselves.  remove the user from admin role before trying to delete them
        haml :'in/profile', :locals => { :message => t.u.delete_me_error_admin, :user => active_user, :nav_hint => "profile" }
      else
        force = params['frankie_says_force_it']
        if force == 'true'
          # delete the user
          active_user.destroy
          log_user_out
          log_user_out # do it twice
          haml :register, :locals => { :message => t.u.delete_me_success,
            :name => "", :email => "", :nav_hint => "register" }
        else
          # throw up a warning screen.
          haml :'in/confirm_delete_self', :locals => { :message => t.u.delete_me_confirmation, :user => active_user, :nav_hint => "" }
        end
      end
    else
      @@log.error("/delete_self called but no-one was logged in. Check the UI and Navigation options in your templates.")
      haml :login, :locals => { :message => t.u.delete_me_error_login, :name => active_user, :nav_hint => "login" }
    end
  end

  # the show the current logged in user's details page
  get '/profile' do
    login_required!
    haml :'in/profile', :locals => { :message => t.u.profile_message, :user => active_user, :nav_hint => "profile" }
  end

  # the edit the current logged in user's details page
  get '/profile/edit' do
    login_required!
    haml :'in/edit_profile', :locals => { :message => t.u.profile_edit_message, :user => active_user, :nav_hint => "edit_profile" }
  end

  post '/profile/edit' do
    login_required!
    user = active_user
    new_email = params['email']
    new_password = params['password']
    new_html_email_pref = params['html_email']
    new_locale = params[:locale]
  
    user_changed = false
    error = false
    message = t.u.profile_edit_success
  
    old_html_email_pref = user.get_preference('HTML_EMAIL').value

    if old_html_email_pref != new_html_email_pref
      user.set_preference('HTML_EMAIL', new_html_email_pref)
      user_changed = true
    end
  
    # if the password is not '' then overwrite the password with the one supplied
    if new_password != ''
      user.password = new_password
      user_changed = true
    end
  
    # if the email is new then deactivate and send a confirmation message
    if new_email != user.email
      if User.email_exists?(new_email)
    	  notify_user_of_email_change_overlap_attempt!(new_email, user.username)
    	  message = t.u.profile_edit_error_email_clash(new_email) + t.u.profile_edit_error
    	  error = true
      else
        user.email = new_email
        user.validated = false
        send_email_update_confirmation_to(user)
        message = t.u.profile_edit_success_email_confirmation(new_email)
        user_changed = true
      end
    end

    # just check the locale code provided is legit.
    if user.locale != new_locale && locale_available?(new_locale)
      user.locale = new_locale
      user_changed = true
    end
  
    if error
      # TODO: Rack provides a standard 'error' collection we can use to be much smarter about returning errors.
      haml :'in/edit_profile', :locals => { :message => message, :user => active_user, :nav_hint => "edit_profile" }
  	elsif user_changed
      user.save!
      #      nuke_session!
      #      user.reload
      refresh_active_user!
      haml :'in/profile', :locals => { :message => message, :user => active_user, :nav_hint => "profile" }
    else
      haml :'in/profile', :locals => { :message => t.u.profile_edit_no_change, :user => active_user, :nav_hint => "profile" }
    end
  end

  # generic userland pages bounce to the logged in home page if logged in, or login page if not.
  get '/in/*' do
    login_required!
    haml :'in/index', :locals => { :message => t.u.hello_message, :user => active_user, :nav_hint => "home" }
  end

###################### AMINISTRATION HANDLERS #############################

  #if logged in and if an admin then list all the users
  get '/users' do
    admin_required! "/"
    # an admin user can list everyone
    user_list = User.all
    haml :'in/list_users', :locals => { :message => t.u.list_users_message(user_list.size),
      :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
  end

  #if logged in and if an admin then you may create a new user.
  get '/user' do
    admin_required! "/"
    haml :'in/new_user', :locals => { :message => t.u.create_user_message,
      :user => active_user, :nav_hint => "new_user" }
  end

  #if logged in and if an admin then you may create a new role.
  get '/role' do
    admin_required! "/"
    haml :'in/new_role', :locals => { :message => t.u.create_role_message,
      :user => active_user, :nav_hint => "new_role" }
  end

  #if logged in and if an admin then you may create a new role.
  post '/role' do
    admin_required! "/"
    new_name = params[:new_name]
    # check the role name doesn't already exist
    if Role.find_by_name(new_name) != nil
      haml :'in/new_role', :locals => { :message => t.u.create_role_error(new_name),
        :user => active_user, :nav_hint => "new_role" }     
    else
      new_role = Role.create( :name => new_name )
      @@log.debug("Created new role with name #{new_role.name}")
      role_list = Role.all
      @@log.debug("There are now #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => t.u.create_role_success(new_name),
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
    end
  end

  #if logged in and if an admin then you may create a new user.
  post '/user' do
    admin_required! "/"
    new_name = params[:username]
    new_email = params[:email]
    new_password = params[:password]
    new_html_pref = params[:html_email]
    new_locale = params[:_locale]

    # check the user name doesn't already exist
    if User.find_by_username(new_name) != nil
      haml :'in/new_user', :locals => { :message => t.u.create_user_username_error(new_name),
        :user => active_user, :nav_hint => "new_user" }     
    elsif User.find_by_email(new_email) != nil
      haml :'in/new_user', :locals => { :message => t.u.create_user_email_error(new_email),
        :user => active_user, :nav_hint => "new_user" }           
    else
      new_user = User.create( :username => new_name, :password => new_password, :email => new_email )
      new_user.set_preference('HTML_EMAIL', new_html_pref)
      new_user.locale = new_locale
      new_user.validated = true # lets not get fancy right now.
      # add the roles
      new_roles = params[:roles]
      if new_roles != nil
        for role in new_roles do
          new_user.add_role(role) unless role == ''
        end
      end
      new_user.save!
      @@log.debug("Created new user with username #{new_user.username}")
      user_list = User.all
      @@log.debug("There are now #{t.users(user_list.size)}")
      haml :'in/list_users', :locals => { :message => t.u.create_user_success(new_name),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    end
  end

  #if logged in and if an admin then you may show the user's details.
  get '/user/:id' do
    admin_required! "/"
    # an admin user can display anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    else
      haml :'in/show_user', :locals => { :message => t.u.show_user_message(target_user.username), :user => active_user, :target_user => target_user, :nav_hint => "show_user" }
    end
  end

  # if logged in and if an admin then you may edit the user's details.
  # here we show the edit form.
  get '/user/edit/:id' do
    admin_required! "/"
    # an admin user can edit anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    else
      haml :'in/edit_user', :locals => { :message => t.u.edit_user_message(target_user.username), :user => active_user, :target_user => target_user, :nav_hint => "edit_user" }
    end
  end

  #if logged in and if an admin then edit the user
  post '/user/edit/:id' do
    admin_required! "/"
    # an admin user can edit anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    else      
      new_email = params['email']
      new_password = params['password']
      new_html_email_pref = params['html_email']
  
      user_changed = false
      error = false
      message = t.u.edit_user_success
  
      old_html_email_pref = target_user.get_preference('HTML_EMAIL').value

      if old_html_email_pref != new_html_email_pref
        target_user.set_preference('HTML_EMAIL', new_html_email_pref)
        user_changed = true
      end
      # if the password is not '' then overwrite the password with the one supplied
      if new_password != ''
        target_user.password = new_password
        user_changed = true
      end
      # if the email is new then deactivate and send a confirmation message
      if new_email != target_user.email
        if User.email_exists?(new_email)
          # don't bother to notify
          message = "#{t.u.edit_user_error_email_clash(new_email)} #{t.u.edit_user_error}"
          error = true
        else
          target_user.email = new_email
          target_user.validated = true
          user_changed = true
        end
      end
      new_locale = params['_locale']  # note different to when editing one's own profile.
      # just check the locale code provided is legit.
      if target_user.locale != new_locale && locale_available?(new_locale)
        target_user.locale = new_locale
        user_changed = true
      end
      new_roles = params[:roles]
      roles_changed = false
      if new_roles.size != target_user.roles.size + 1 # remember the 'none' option.
        roles_changed = true
      else
        # same number of roles so lets see if they actually match
        for new_role in new_roles do
          roles_changed &&= !target_user.has_role?(new_role)
        end
      end
      if roles_changed
        target_user.replace_roles(new_roles)
        user_changed = true
      end
      if error
        @@log.debug("Editing user with username #{target_user.username} but an error occured. #{message}")
        haml :'in/edit_user', :locals => { :message => message, :user => active_user, :target_user => target_user, :nav_hint => "edit_user" }
      elsif user_changed
        target_user.save!
        @@log.debug("Edited user with username #{target_user.username}")
        haml :'in/show_user', :locals => { :message => message, :user => active_user, :target_user => target_user, :nav_hint => "show_user" }
      else
        haml :'in/show_user', :locals => { :message => t.u.edit_user_no_change, :user => active_user, :target_user => target_user, :nav_hint => "profile" }
      end
    end
  end

  #if logged in and if an admin then edit the user
  post '/user/delete/:id' do
    admin_required! "/"
    # an admin user can delete anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size),
        :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    elsif target_user.has_role?('superuser')
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.error_cant_delete_superuser_message, :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    else
      tu_name = target_user.username
      target_user.destroy
      @@log.debug("Deleted user with username #{tu_name}")
      user_list = User.all
      @@log.debug("There are now #{t.users(user_list.size)}")
      haml :'in/list_users', :locals => { :message => t.u.delete_user_success_message(tu_name), :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    end
  end

  #if logged in and if an admin then list all the users
  get '/roles' do
    admin_required! "/"
    # an admin user can list roles
    role_list = Role.all
    @@log.debug("There are #{t.roles(role_list.size)}")
    haml :'in/list_roles', :locals => { :message => t.u.list_roles_message(role_list.size), :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
  end

  get '/role/edit/:name' do
    admin_required! "/"
    target_role = Role.find_by_name(params[:name])
    if target_role == nil
      role_list = Role.all
      @@log.debug("No roles with that name. There are #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => " #{t.u.error_role_unknown_message}. #{t.u.list_roles_message(role_list.size)}",
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
    elsif is_blessed_role?(target_role)
      role_list = Role.all
      haml :'in/list_roles', :locals => { :message => t.u.error_cant_edit_blessed_role_message(target_role.name) + '. ' + t.u.list_roles_message(role_list.size),
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
    else
      haml :'in/edit_role', :locals => { :message => t.u.edit_role_message(target_role.name), :user => active_user, :target_role => target_role, :nav_hint => "edit_role" }
    end
  end

  post '/role/edit/:name' do
    admin_required! "/"
    new_name = params[:new_name]
    target_role = Role.find_by_name(params[:name])
    if target_role == nil
      role_list = Role.all
      @@log.debug("No roles with that name. There are #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => " #{t.u.error_role_unknown_message}. #{t.u.list_roles_message(role_list.size)}",
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
    elsif is_blessed_role?(target_role)
      role_list = Role.all
      @@log.debug("That role was 'blessed' and can't be changed. There are #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => t.u.error_cant_edit_blessed_role_message(target_role.name) + '. ' + t.u.list_roles_message(role_list.size),
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
    elsif new_name == target_role.name
      # no changes.
      role_list = Role.all
      @@log.debug("That role name was not changed. There are #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => t.u.edit_role_no_change,
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }            
    elsif Role.find_by_name(new_name) != nil  # there's already a role called #{newname}
      # TODO: for now just call error but a better solution is to offer to merge the roles.
      #       Need to define business logic for that so it's beyond the scope of Frank.
      role_list = Role.all
      @@log.debug("That is the name of an existing role. There are #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => t.u.error_dupe_role_name_message(new_name) + '. ' + t.u.list_roles_message(role_list.size),
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }            
    else
      # change the name of the role.  How does this affect other users in that role? (TODO: test that)
      target_role.name = new_name
      target_role.save!
      @@log.debug("Saved #{target_role.name}")
      role_list = Role.all
      @@log.debug("There are now #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => t.u.edit_role_success,
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
    end
  end

  post '/role/delete/:name' do
    admin_required! "/"
    target_role = Role.find_by_name(params[:name])
    if target_role == nil
      role_list = Role.all
      @@log.debug("That role was unknown. There are #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => " #{t.u.error_role_unknown_message}. #{t.u.list_roles_message(role_list.size)}",
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }
    elsif is_blessed_role?(target_role)
      role_list = Role.all
      @@log.debug("That role was 'blessed' and can't be deleted. There are #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => t.u.error_cant_delete_blessed_role_message(target_role.name) + '. ' + t.u.list_roles_message(role_list.size),
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
    else
      target_role.destroy
      role_list = Role.all
      @@log.debug("That role was deleted. There are #{t.roles(role_list.size)}")
      haml :'in/list_roles', :locals => { :message => t.u.delete_role_message(target_role.name), 
        :user => active_user, :role_list => role_list, :nav_hint => "list_roles" }      
    end
  end



end
