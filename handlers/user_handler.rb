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
    elsif is_remembered_user?
      name = active_username
      log_user_out
      haml :login, :locals => { :message => "You have logged out completely #{name}. Please log in again to continue", :name => "" }
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
      log_user_out # do it twice
      haml :register, :locals => { :message => "Your user record has been deleted. You must register again to log in", :name => "" }
    else
      haml :login, :locals => { :message => "You are not logged in", :name => active_user }
    end
  end

  # the show the current logged in user's details page
  get '/in/show_user' do
    login_required!
    haml :'in/show_user', :locals => { :message => "Show details:", :user => active_user }
  end

  # the edit the current logged in user's details page
  get '/in/edit_user' do
    login_required!
    haml :'in/edit_user', :locals => { :message => "Edit your details:", :user => active_user }
  end

  post '/in/editing_user' do
    login_required!
    user = active_user
    new_email = params['email']
    new_password = params['password']
    new_html_email_pref = params['html_email']
    
    user_changed = false
    error = false
    message = "Your details have been saved"
    
    old_html_email_pref = user.get_preference('HTML_EMAIL').value
    puts "DEBUG --> HTML Email pref was '" + old_html_email_pref + "'"

    if old_html_email_pref != new_html_email_pref
      user.set_preference('HTML_EMAIL', new_html_email_pref)
      puts "DEBUG --> HTML Email pref changed to '" + new_html_email_pref + "'"
      user_changed = true
    end
    # if the password is not '' then overwrite the password with the one supplied
    if new_password != ''
      user.password = new_password
      user_changed = true
    end
    # if the email is new then deactivate and send a confirmation message
    if new_email != user.email
      user.email = new_email
      if User.email_exists?(new_email)
    	  notify_user_of_email_change_overlap_attempt!(new_email,user.username)
    	  message = "A user with email '#{new_email}' already exists. Changes were not saved"
    	  error = true
      else
        user.validated = false
        send_email_update_confirmation_to(user)
        message = "A confirmation email has been sent to #{new_email}. Once you log out you will not be able to log in again until you confirm your email address."
        user_changed = true
      end
    end
    if error
      haml :'in/edit_user', :locals => { :message => message, :user => active_user }
  	elsif user_changed
      user.save!
      nuke_session!
      user.reload
      log_user_in(user) # puts the updated details back into the session.
      haml :'in/show_user', :locals => { :message => message, :user => active_user }
    else
      haml :'in/show_user', :locals => { :message => "Your details were not changed", :user => active_user }
    end
  end

  # generic userland pages bounce to the logged in home page if logged in, or login page if not.
  get '/in/*' do
    login_required!
    haml :'in/index', :locals => { :message => "Hello", :user => active_user }
  end
end
