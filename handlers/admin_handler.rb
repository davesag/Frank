#!usr/bin/ruby

require 'rubygems'
require 'frank'
require 'haml'
require 'active_record'
require 'logger'

require 'models/user'
require 'models/role'
require 'models/preference'

class AdminHandler < Frank

  #if logged in and if an admin then list all the users
  get '/users' do
    if !is_logged_in?
      haml :login, :locals => { :message => t.u.login_message, :name => active_username, :nav_hint => "login" }
    elsif active_user.has_role?('admin')
      # an admin user can list everyone
      user_list = User.all
      haml :'in/list_users', :locals => { :message => t.u.list_users_message, :user => active_user, :user_list => user_list, :nav_hint => "list_users" }
    else
      redirect "/"
    end
  end

  #if logged in and if an admin then edit the user
  get '/user/edit/:id' do
    if !is_logged_in?
      haml :login, :locals => { :message => t.u.login_message, :name => active_username, :nav_hint => "login" }
    elsif active_user.has_role?('admin')
      # an admin user can list everyone
      target_user = User.find_by_id(params[:id])
      haml :'in/edit_user', :locals => { :message => t.u.list_users_message, :user => active_user, :target_user => target_user, :nav_hint => "edit_user" }
    else
      redirect "/"
    end
  end

end
