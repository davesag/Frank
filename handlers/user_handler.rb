#!usr/bin/ruby

require 'rubygems'
require 'frank'
require 'haml'
require 'active_record'
require 'logger'

require 'models/user'
require 'models/role'
require 'models/preference'

class UserHandler < Frank

  #logout action  - nuke user from session, display login form and thank user
  get '/logout' do
    if is_logged_in?
      name = active_user.username
      log_user_out
      haml :login, :locals => { :message => "Thanks for visiting #{name}. Please log in again to continue", :name => "#{name}" }
    else
      haml :login, :locals => { :message => "You were not logged in. Please log in to continue", :name => "" }
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
end
