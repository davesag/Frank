#!usr/bin/ruby

require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/r18n'
require 'sinatra/flash'
require 'active_record'
require 'logger'
require 'pony'
require 'erb'
require 'haml'

#and frank's helpers
require 'sinatra/template_helpers'
require 'sinatra/email_helpers'
require 'sinatra/authorisation_helpers'
require 'sinatra/common_helpers'
require 'sinatra/form_helpers'

class Frank < Sinatra::Base
  enable  :sessions
  set :root, File.dirname(__FILE__)
  set :models, Proc.new { root && File.join(root, 'models') }
  register Sinatra::R18n
  register Sinatra::Flash
  helpers Sinatra::TemplateHelpers
  helpers Sinatra::EmailHelpers
  helpers Sinatra::AuthorisationHelpers
  helpers Sinatra::CommonHelpers
  helpers Sinatra::FormHelpers

  @active_user = nil         # the active user is reloaded on each request in the before method.

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
    ActiveRecord::Base.logger.level = Logger::WARN      #not interested in database stuff right now.

    dbconfig = YAML.load(File.read('config/database.yml'))
    ActiveRecord::Base.establish_connection dbconfig['development']

    @models_are_loaded = false
    load_models
  end

  configure :production do  
    set :environment, :production
    @@log = Logger.new(STDOUT)  # TODO: should look for a better option than this.
    @@log.level = Logger::INFO
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
  
######################   TEST ROUTES   #################################

  get '/form_test' do
    flash.now[:message] = "This is a test of an active form"
    clear_form
    add_field("testfield1", "test 1", "text", true, nil, "name", nil )
    add_field("testfield2", "test@test.test", "text", true, 'email', "Email", nil )
    add_field("testfield3", '', "password", false, nil, "Password", nil )
    add_field("testfield4", 'test 3 is the most wonderful test of all.', "textarea", true, nil, "Blurb", nil )
    add_field("testfield5", 'false', "select", true, nil, "Happy?", [{ :value => 'true', :text => 'Yes'}, { :value => 'false', :text => 'No'}] )
    add_field("testfield6", 'some value', 'hidden', true, nil, nil, nil)
#    add_field("name", "value", "type", "required", "validation", "label_text", "options" )
    haml :active_form_test, :locals => { :nav_hint => "test" }
  end

  post '/form_test' do
    update_form
    if form_okay?
      if form_changed?
        flash.now[:tip] = "Your changes were saved"
      else
        flash.now[:warning] = "There were no changes."
      end
    else
      flash.now[:error] = "There were errors in your form"
    end
    haml :active_form_test, :locals => { :nav_hint => "test" }
  end

  ######################   GUEST ROUTES   #################################

  # home page - display login form, or divert to user home
  get '/' do
    login_required! 
    flash.now[:message] = t.u.welcome_in
    haml :'in/index', :locals => { :nav_hint => "home" }
  end

  # privacy page - display privacy text
  get '/privacy' do
    flash.now[:message] = is_logged_in? ? t.u.privacy_title_in : t.u.privacy_title_out
    haml :'privacy', :locals => { :nav_hint => "privacy" }
  end

  # about page - display about text
  get '/about' do
    flash.now[:message] = is_logged_in? ? t.u.about_title_in : t.u.about_title_out
  	haml :about, :locals => { :nav_hint => "about" }
  end

  # privacy page - display privacy text
  get '/terms' do
    flash.now[:message] = is_logged_in? ? t.u.terms_title_in : t.u.terms_title_out
  	haml :terms, :locals => { :nav_hint => "terms" }
  end

  # login request - display login form, or divert to user home
  get '/login' do
    if is_logged_in?
      flash.now[:message] = t.u.welcome_in
      haml :'in/index', :locals => { :nav_hint => "home" }
    else
      flash.now[:message] = t.u.login_message
      prep_login_form remembered_user_name
  	  haml :login, :locals => { :nav_hint => "login" }
    end
  end

  #login action - check credentials and load user into session
  post '/login' do
    update_form
    if form_okay?
      name = params['username']
      pass = params['password']
      entering_user = auth_user(name, pass)
      if entering_user != nil
        log_user_in!(entering_user)
        flash.now[:tip] = t.u.login_success(active_user_name)
        haml :'in/index', :locals => { :nav_hint => "home" }
      else
        flash.now[:error] = t.u.login_error
        haml :login, :locals => { :nav_hint => "login" }
      end
    else
      flash.now[:error] = "There were errors in your form"
      haml :login, :locals => { :nav_hint => "login" }
    end
  end

  # contact request - display contact form
  get '/contact' do
    clear_form
    add_field('subject', '', 'text', "required", nil, 'Subject', nil )
    #    add_field("name", "value", "type", "required", "validation", "label_text", "options" )
    if is_logged_in?
      flash.now[:message] = t.u.contact_title_in
    else
      flash.now[:message] = t.u.contact_title_out
      add_field('email', '', 'text', "required", 'email', 'Email', nil )
    end
    add_field('message', '', 'textarea', "required", nil, 'Message', nil )
    haml :contact, :locals => { :nav_hint => "contact" }
  end

  # handle contact request - send email to davesag@gmail.com and display a thanks message.
  post '/contact' do
    update_form
    if form_okay?
      email_from = is_logged_in? ? active_user.email : params[:email]
      send_message_to_webmaster( email_from, params[:subject], params[:message])
      if is_logged_in?
        flash.now[:message] = t.u.contact_send_message_in
        haml :message_only, :locals => { :detailed_message => t.u.contact_send_message_detailed_in, :nav_hint => "contact" }
      else
        flash.now[:message] = t.u.contact_send_message_out
    	  haml :message_only, :locals => { :detailed_message => t.u.contact_send_message_detailed_out, :nav_hint => "contact" }
      end
    else
      flash.now[:error] = "There were errors in your form"
      haml :contact, :locals => { :nav_hint => "contact" }
    end

  end

  # registration request - display registration form, or divert to user home if logged in
  get '/register' do
    if is_logged_in?
      flash.now[:error] = t.u.register_error_already_as(active_user_name)
      haml :'in/index', :locals => { :nav_hint => "home" }
    elsif is_remembered_user?
      flash.now[:error] = t.u.register_error
      prep_login_form remembered_user_name
      haml :login, :locals => { :nav_hint => "login" }
	  else
      flash.now[:message] = t.u.register_message
      prep_registration_form
  	  haml :register, :locals => { :nav_hint => "register" }
    end
  end

  # forgot password request
  get '/forgot_password' do
    if is_logged_in?
      flash.now[:error] = t.u.forgot_password_error_already_as(active_user_name)
      haml :'in/index', :locals => { :nav_hint => "home" }
	  else
      flash.now[:message] = t.u.forgot_password
      clear_form
      add_field('email', '', 'text', true, 'email', t.labels.email_label, nil )
  	  haml :forgot_password, :locals => { :nav_hint => "forgot_password" }
    end
  end

  post '/forgot_password' do
    if is_logged_in?
      flash.now[:error] = t.u.forgot_password_error_already_as(active_user_name)
      haml :'in/index', :locals => { :nav_hint => "home" }
	  else
      update_form
      if form_okay?
  	    user = User.find_by_email(params[:email].downcase)

  	    if user == nil
          flash.now[:error] = t.u.forgot_password_error
          add_error('email', t.u.forgot_password_error)
          haml :forgot_password, :locals => {:nav_hint => "forgot_password" }	      
        else
          user.password_reset = true
          user.save!
          send_password_reset_to(user)
          flash.now[:tip] = t.u.forgot_password_instruction
      	  haml :message_only, :locals => { :detailed_message => t.u.forgot_password_instruction_detail, :nav_hint => "forgot_password" }
        end
      else
        flash.now[:error] = "There were errors in your form"
    	  haml :forgot_password, :locals => { :nav_hint => "forgot_password" }
      end
    end
  end

  get '/reset_password/:token' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || !user.password_reset?
      flash.now[:error] = t.u.token_expired_error
      prep_login_form ''
      haml :login, :locals => {:nav_hint => "login"}
    else
      flash.now[:tip] = t.u.forgot_password_instruction_email
      clear_form
      add_field('token', user.validation_token, 'hidden', "required", nil, t.labels.password_label, nil )
      add_field('password', '', 'password', "required", nil, t.labels.password_label, nil )
      haml :reset_password, :locals => { :nav_hint => "forgot_password" }
    end
  end

  post '/reset_password' do
    update_form
    if form_okay?
      user = User.find_by_validation_token(params[:token])
      if user == nil || !user.password_reset?
        flash.now[:error] = t.u.token_expired_error
        prep_login_form ''
        haml :login, :locals => { :nav_hint => "login"}
      else
        # actually change the password (note this is stored as a bcrypted string, not in clear text)
        user.password = params[:password]
        user.password_reset = false   # this is a secuity measure to prevent  someone with a matching token resetting a
                                      # password that was not requested to be reset.
        user.shuffle_token!           # we can't delete a token and they must be unique so we shuffle it after use.
        user.save!
        remember_user_name(user.username)
        flash.now[:tip] = t.u.forgot_password_success
        prep_login_form remembered_user_name
        haml :login, :locals => { :nav_hint => "login" }
      end
    else
      flash.now[:error] = "There were errors in your form"
  	  haml :reset_password, :locals => { :nav_hint => "forgot_password" }
    end
  end

######################  REGISTRATION ROUTES #############################

  # registration action - check username and email are unique and valid and display 'check your email' page
  post '/registration' do
    if is_logged_in?
      flash.now[:error] = t.u.register_error_already_as(active_user_name)
      clear_form
      haml :'in/index', :locals => { :nav_hint => "home" }
    else
      update_form
      if form_okay?
        email = params['email']
        name = params['username']
        terms = params['terms']
        if 'true' != terms
          flash.now[:error] = t.u.register_error_terms
          add_error('terms', t.u.register_error_terms)
      	  haml :register, :locals => { :nav_hint => "register" }        
        else
          if User.username_exists?(name)
            flash.now[:error] = t.u.register_error_username(name)
            add_error('username', t.u.register_error_username(name))
        	  haml :register, :locals => { :nav_hint => "register" }
          elsif User.email_exists?(email)
        	  notify_user_of_registration_overlap_attempt!(email,name)
            flash.now[:error] = t.u.register_error_email(email)
            add_error('username', t.u.register_error_email(email))
        	  haml :register, :locals => { :nav_hint => "register" }
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
            flash.now[:tip] = t.u.register_success(email)
            prep_login_form name
            haml :login, :locals => { :nav_hint => "login" }
          end
        end
      else
        flash.now[:error] = "There were errors in your form"
        haml :register, :locals => { :nav_hint => "register" }
      end
    end
  end

  # checks the user against the validation token.
  get '/validate/:token' do
    user = User.find_by_validation_token(params[:token])
    if user == nil || user.validated?
      flash.now[:error] = t.u.token_expired_error
      clear_form                    # a security precaution.
      haml :index, :locals => { :nav_hint => "home"}
    else
      user.validated = true
      user.shuffle_token!           # we can't delete a token and they must be unique so we shuffle it after use to prevent reuse.
      user.save!
      flash.now[:tip] = t.u.register_success_confirmed
      prep_login_form user.username
      haml :login, :locals => { :nav_hint => "login" }
    end
  end

##########################  USER ROUTES   ###############################

  #logout action  - nuke user from session, display login form and thank user
  get '/logout' do
    if is_logged_in?
      log_user_out
      flash.now[:message] = t.u.logout_message(active_user_name)
    elsif is_remembered_user?
      log_user_out
      flash.now[:message] = t.u.logout_completely(remembered_user_name)
    else
      flash.now[:error] = t.u.logout_error
    end
    prep_login_form remembered_user_name
    haml :login, :locals => {:nav_hint => "login" }
  end

  # a user can delete themselves.
  post '/delete_self' do    
    if is_logged_in?
      if active_user.has_role?('admin')
        @@log.error("/delete_self called by an admin. Admin's can't delete themselves. Check the UI and Navigation options in your templates.")
        # admin users can not delete themselves.  remove the user from admin role before trying to delete them
        flash.now[:error] = t.u.delete_me_error_admin
        haml :'in/profile', :locals => { :nav_hint => "profile" }
      else
        force = params['frankie_says_force_it']
        if force == 'true'
          # delete the user
          active_user.destroy
          log_user_out
          log_user_out # do it twice
          flash.now[:tip] = t.u.delete_me_success
          prep_registration_form          
          haml :register, :locals => { :username => "", :email => "", :nav_hint => "register" }
        else
          # throw up a warning screen.
          flash.now[:warning] = t.u.delete_me_confirmation
          haml :'in/confirm_delete_self', :locals => {:nav_hint => "" }
        end
      end
    else
      @@log.error("/delete_self called but no-one was logged in. Check the UI and Navigation options in your templates.")
      flash.now[:message] = t.u.delete_me_error_login
      prep_login_form active_user_name
      haml :login, :locals => { :username => active_user_name, :nav_hint => "login" }
    end
  end

  # the show the current logged in user's details page
  get '/profile' do
    login_required!
    flash.now[:message] = t.u.profile_message
    haml :'in/profile', :locals => { :nav_hint => "profile" }
  end

  # the edit the current logged in user's details page
  get '/profile/edit' do
    login_required!
    flash.now[:message] = t.u.profile_edit_message
    haml :'in/edit_profile', :locals => { :nav_hint => "edit_profile" }
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
      flash.now[:error] = message
      haml :'in/edit_profile', :locals => { :nav_hint => "edit_profile" }
  	elsif user_changed
      user.save!
      refresh_active_user!
      flash.now[:message] = message
      haml :'in/profile', :locals => { :nav_hint => "profile" }
    else
      flash.now[:warning] = t.u.profile_edit_no_change
      haml :'in/profile', :locals => { :nav_hint => "profile" }
    end
  end

  # generic userland pages bounce to the logged in home page if logged in, or login page if not.
  get '/in/*' do
    login_required!
    flash.now[:message] = t.u.hello_message
    haml :'in/index', :locals => {:nav_hint => "home" }
  end

###################### AMINISTRATION ROUTES #############################

  #if logged in and if an admin then list all the users
  get '/users' do
    admin_required! "/"
    # an admin user can list everyone
    user_list = User.all(:order => "LOWER(username) ASC")
    flash.now[:message] = t.u.list_users_message(user_list.size)
    haml :'in/list_users', :locals => { :user_list => user_list, :nav_hint => "list_users" }
  end

  #if logged in and if an admin then you may create a new user.
  get '/user' do
    admin_required! "/"
    flash.now[:message] = t.u.create_user_message
    haml :'in/new_user', :locals => { :nav_hint => "new_user" }
  end

  #if logged in and if an admin then you may create a new role.
  get '/role' do
    admin_required! "/"
    flash.now[:message] = t.u.create_role_message
    haml :'in/new_role', :locals => { :nav_hint => "new_role" }
  end

  #if logged in and if an admin then you may create a new role.
  post '/role' do
    admin_required! "/"
    new_name = params[:new_name]
    # check the role name doesn't already exist
    if Role.find_by_name(new_name) != nil
      flash.now[:error] = t.u.create_role_error(new_name)
      haml :'in/new_role', :locals => { :nav_hint => "new_role" }     
    else
      new_role = Role.create( :name => new_name )
#      @@log.debug("Created new role with name #{new_role.name}")
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("There are now #{t.roles(role_list.size)}")
      flash.now[:tip] = t.u.create_role_success(new_name)
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }
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
      flash.now[:error] = t.u.create_user_username_error(new_name)
      haml :'in/new_user', :locals => { :nav_hint => "new_user" }     
    elsif User.find_by_email(new_email) != nil
      flash.now[:error] = t.u.create_user_email_error(new_email)
      haml :'in/new_user', :locals => { :nav_hint => "new_user" }           
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
#      @@log.debug("Created new user with username #{new_user.username}")
      user_list = User.all(:order => "LOWER(username) ASC")               # TODO: Redundant given that all usernames are lowercase.

#      require 'ruby-debug'
#      debugger

#      @@log.debug("There are now #{t.users(user_list.size)}")
      flash.now[:tip] = t.u.create_user_success(new_name)
      haml :'in/list_users', :locals => { :user_list => user_list, :nav_hint => "list_users" }
    end
  end

  #if logged in and if an admin then you may show the user's details.
  get '/user/:id' do
    admin_required! "/"
    # an admin user can display anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all(:order => "LOWER(username) ASC")
      flash.now[:error] =  t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size)
      haml :'in/list_users', :locals => { :user_list => user_list, :nav_hint => "list_users" }
    else
      flash.now[:message] =  t.u.show_user_message(target_user.username)
      haml :'in/show_user', :locals => { :target_user => target_user, :nav_hint => "show_user" }
    end
  end

  # if logged in and if an admin then you may edit the user's details.
  # here we show the edit form.
  get '/user/edit/:id' do
    admin_required! "/"
    # an admin user can edit anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all(:order => "LOWER(username) ASC")
      flash.now[:error] =  t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size)
      haml :'in/list_users', :locals => { :user_list => user_list, :nav_hint => "list_users" }
    else
      flash.now[:message] =  t.u.edit_user_message(target_user.username)
      haml :'in/edit_user', :locals => { :target_user => target_user, :nav_hint => "edit_user" }
    end
  end

  #if logged in and if a superuser, or an admin (and the user is not super or admin) then edit the user
  post '/user/edit/:id' do    admin_required! "/"
    # a superuser can edit anyone
    # an admin user can edit anyone who is not a superuser or admin.
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all(:order => "LOWER(username) ASC")
      flash.now[:error] =  t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size)
      haml :'in/list_users', :locals => { :user_list => user_list, :nav_hint => "list_users" }
    elsif active_user.can_edit_user?(target_user)
      new_email = params[:email].downcase           # emails are always stored in lowercase so always compare as lowercase.
      new_password = params[:password]
      new_html_email_pref = params[:html_email]
  
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
      # if the email is new then silently update it, assuming no email clash
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
#        require 'ruby-debug'
#        debugger
        new_roles.delete("")  # eliminate the NONE option.
        for new_role in new_roles do
          roles_changed ||= !target_user.has_role?(new_role)
        end
      end
      if roles_changed
        target_user.replace_roles(new_roles)
        user_changed = true
      end
      if error
#        @@log.debug("Editing user with username #{target_user.username} but an error occured. #{message}")
        flash.now[:error] =  message
        haml :'in/edit_user', :locals => { :target_user => target_user, :nav_hint => "edit_user" }
      elsif user_changed
        target_user.save!
#        @@log.debug("Edited user with username #{target_user.username}")
        flash.now[:tip] =  message
        haml :'in/show_user', :locals => { :target_user => target_user, :nav_hint => "show_user" }
      else
        flash.now[:warning] =  t.u.edit_user_no_change
        haml :'in/show_user', :locals => { :target_user => target_user, :nav_hint => "profile" }
      end
    else
      user_list = User.all(:order => "LOWER(username) ASC")
      flash.now[:error] =  t.u.edit_user_permission_error + '. ' + t.u.list_users_message(user_list.size)
      haml :'in/list_users', :locals => { :user_list => user_list, :nav_hint => "list_users" }  
    end
  end

  #if logged in and if an admin or superuser then delete the user
  # can't delete a superuser however.
  post '/user/delete/:id' do
    admin_required! "/"
    # an admin user can delete anyone
    target_user = User.find_by_id(params[:id])
    if target_user == nil
      user_list = User.all(:order => "LOWER(username) ASC")
      flash.now[:error] =  t.u.error_user_unknown_message + '. ' + t.u.list_users_message(user_list.size)
      haml :'in/list_users', :locals => { :user_list => user_list, :nav_hint => "list_users" }
    elsif target_user.has_role?('superuser')
      user_list = User.all(:order => "LOWER(username) ASC")
      flash.now[:error] =  t.u.error_cant_delete_superuser_message
      haml :'in/list_users', :locals => { :user_list => user_list, :nav_hint => "list_users" }
    else
      tu_name = target_user.username
      target_user.destroy
#      @@log.debug("Deleted user with username #{tu_name}")
      user_list = User.all(:order => "LOWER(username) ASC")
#      @@log.debug("There are now #{t.users(user_list.size)}")
      flash.now[:tip] =  t.u.delete_user_success_message(tu_name)
      haml :'in/list_users', :locals => { :user_list => user_list, :nav_hint => "list_users" }
    end
  end

  #if logged in and if an admin then list all the users
  get '/roles' do
    admin_required! "/"
    # an admin user can list roles
    role_list = Role.all(:order => "LOWER(name)")
#    @@log.debug("There are #{t.roles(role_list.size)}")
    flash.now[:message] =  t.u.list_roles_message(role_list.size)
    haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }
  end

  get '/role/edit/:username' do
    admin_required! "/"
    target_role = Role.find_by_name(params[:username])
    if target_role == nil
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("No roles with that name. There are #{t.roles(role_list.size)}")
      flash.now[:error] =  "#{t.u.error_role_unknown_message}. #{t.u.list_roles_message(role_list.size)}"
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }
    elsif is_blessed_role?(target_role)
      role_list = Role.all(:order => "LOWER(name)")
      flash.now[:error] =  t.u.error_cant_edit_blessed_role_message(target_role.name) + '. ' + t.u.list_roles_message(role_list.size)
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }      
    else
      flash.now[:message] =  t.u.edit_role_message(target_role.name)
      haml :'in/edit_role', :locals => { :target_role => target_role, :nav_hint => "edit_role" }
    end
  end

  post '/role/edit/:username' do
    admin_required! "/"
    new_name = params[:new_name]
    target_role = Role.find_by_name(params[:username])
    if target_role == nil
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("No roles with that name. There are #{t.roles(role_list.size)}")
      flash.now[:error] =  "#{t.u.error_role_unknown_message}. #{t.u.list_roles_message(role_list.size)}"
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }
    elsif is_blessed_role?(target_role)
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("That role was 'blessed' and can't be changed. There are #{t.roles(role_list.size)}")
      flash.now[:error] =  t.u.error_cant_edit_blessed_role_message(target_role.name) + '. ' + t.u.list_roles_message(role_list.size)
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }
    elsif new_name == target_role.name
      # no changes.
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("That role name was not changed. There are #{t.roles(role_list.size)}")
      flash.now[:warning] =  t.u.edit_role_no_change
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }            
    elsif Role.find_by_name(new_name) != nil  # there's already a role called #{newname}
      # TODO: for now just call error but a better solution is to offer to merge the roles.
      #       Need to define business logic for that so it's beyond the scope of Frank.
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("That is the name of an existing role. There are #{t.roles(role_list.size)}")
      flash.now[:error] =   t.u.error_dupe_role_name_message(new_name) + '. ' + t.u.list_roles_message(role_list.size)
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }            
    else
      # change the name of the role.  How does this affect other users in that role? (TODO: test that)
      target_role.name = new_name
      target_role.save!
#      @@log.debug("Saved #{target_role.name}")
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("There are now #{t.roles(role_list.size)}")
      flash.now[:tip] =  t.u.edit_role_success
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }      
    end
  end

  post '/role/delete/:name' do
    admin_required! "/"
    target_role = Role.find_by_name(params[:name])
    if target_role == nil
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("That role was unknown. There are #{t.roles(role_list.size)}")
      flash.now[:error] =  "#{t.u.error_role_unknown_message}. #{t.u.list_roles_message(role_list.size)}"
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }
    elsif is_blessed_role?(target_role)
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("That role was 'blessed' and can't be deleted. There are #{t.roles(role_list.size)}")
      flash.now[:error] =  t.u.error_cant_delete_blessed_role_message(target_role.name) + '. ' + t.u.list_roles_message(role_list.size)
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }      
    else
      target_role.destroy
      role_list = Role.all(:order => "LOWER(name)")
#      @@log.debug("That role was deleted. There are #{t.roles(role_list.size)}")
      flash.now[:message] =  t.u.delete_role_message(target_role.name)
      haml :'in/list_roles', :locals => { :role_list => role_list, :nav_hint => "list_roles" }      
    end
  end

end
