#!usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/r18n'
require 'sinatra/template_helpers'
require 'pony'
require 'logger'
require 'erb'
require 'haml'

module Sinatra
  module AuthorisationHelpers

    #################       LOGGING IN AND OUT AND SO FORTH     ###########################

    # bounces the user to the login page if they are not logged in.
    def login_required! 
      if ! is_logged_in? 
        redirect '/login' 
      end 
    end 

    # bounces the user to the login page if they are not logged in,
    # and to whichever path is supplied as a bounce path
    # if they are logged in but not an admin or superuser.
    def admin_required!(bounce)
      if !is_logged_in? 
        redirect '/login' 
      end
      if !(active_user.has_role?('admin') || active_user.has_role?('superuser'))
        redirect bounce
      end
    end 

    # bounces the user to the login page if they are not logged in,
    # and to whichever path is supplied as a bounce path
    # if they are logged in but not a superuser.
  #  def superuser_required!(bounce)
  #    if !is_logged_in? 
  #      redirect '/login' 
  #    end
  #    if !active_user.has_role?('superuser')
  #      redirect bounce
  #    end
  #  end 

    # ther user is logged in if the @active_user != nil.
    def is_logged_in?
      @active_user != nil
    end

    # load the supplied user into the @active_user instance attribute.
    # and set the various session keys and locale
    def log_user_in!(user)
      @active_user = user
      session[:user] = user.id
      session[:remembered_username] = user.username
      if @active_user.locale != nil
        session[:locale] = @active_user.locale
      end
    end

    def refresh_active_user!
      if session[:user] != nil
        # there is a currently logged in user so load her up
        @active_user = User.find_by_id(session[:user])
        if @active_user.locale != nil
          session[:locale] = @active_user.locale
        end
      end
    end

    # if there is an active user then nil the @active_user and the session[:user]
    # else nil session[:remembered_username]
    def log_user_out
      if session[:user] != nil
        # there is a currently logged in user
        session[:user] = nil
        @active_user = nil
      else  #there is no active user, ie logout has been called before.
        # nuke the remembered username
        session[:remembered_username] = nil
      end
    end

    def active_user
      return @active_user
    end

    def is_remembered_user?
      session[:remembered_username] != nil
    end

    def active_user_name
      if session[:user] == nil
        return ""
      end
      return session[:user]
    end

    def remember_user_name(username)
      session[:remembered_username] = username
    end

    def remembered_user_name
      if session[:remembered_username] == nil
        return ""
      end
      return session[:remembered_username]
    end

    def auth_user(username, password)
      return User.login(username, password)
    end


  end

  helpers AuthorisationHelpers

end
