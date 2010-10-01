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
end
