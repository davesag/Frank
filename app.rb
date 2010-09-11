#!usr/bin/ruby

require 'rubygems'
require 'sinatra'
require 'haml'
require 'active_record'
require 'logger'

require 'models/user'
require 'models/preference'

enable :sessions

CURRENT_USER_KEY = 'ACTIVE_TEST_APP_USER'

log = Logger.new(STDOUT)
log.level = Logger::DEBUG
log.info("Frank walks onto the stage.")

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database =>  '.FrankData.sqlite3.db'
ActiveRecord::Base.logger = Logger.new(STDOUT)

# all tempolates within /in/ need to use the logged in user template
# we will also be using Haml to send HTML formatted email
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
end

def log_user_out
  session[CURRENT_USER_KEY] = nil
end

def active_user
  session[CURRENT_USER_KEY]
end

def auth_user(username, password)
  User.login(username, password)
end

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

#logout action  - nuke user from session, display login form and thank user
get '/logout' do
  if is_logged_in?
    name = active_user.username
    log_user_out
    haml :login, :locals => { :message => "Thanks for visiting #{name}. Please log in again to continue", :name => "" }
  else
    haml :login, :locals => { :message => "You were not logged in. Please log in to continue", :name => "" }
  end
end

#login action - check credentials and load user into session
post '/login' do
  aName = params['username']
  aPass = params['password']
  aUser = auth_user(aName, aPass)
  if aUser != nil
    log_user_in(aUser)
    haml :'in/index', :locals => { :message => "You have logged in as", :user => aUser }
  else
    haml :login, :locals => { :message => "Unknown User/Password combination, please try again", :name => "" }
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

# a user can delete themselves.
post '/delete_self' do
  if is_logged_in?
    # delete the user
    active_user.destroy
    log_user_out
    haml :register, :locals => { :message => "Your user record has been deleted. You must register again to log in", :name => "" }
  else
    haml :login, :locals => { :message => "You are not logged in", :name => "" }
  end
end

# the show the current logged in user details page
get '/in/show_user' do
  login_required!
  haml :'in/show_user', :locals => { :message => "Show details:", :user => active_user }
end

# generic userland pages bounce to the logged in home page if logged in, or login page if not.
get '/in/*' do
  login_required!
  haml :'in/index', :locals => { :message => "Hello", :user => active_user }
end

