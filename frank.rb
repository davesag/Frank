#!usr/bin/ruby

require 'rubygems'
require 'sinatra/base'
require 'active_record'
require 'logger'

class Frank < Sinatra::Base
  enable  :sessions
  set :root, File.dirname(__FILE__)
  set :handlers, Proc.new { root && File.join(root, 'handlers') }
  
  CURRENT_USER_KEY = 'ACTIVE_TEST_APP_USER'

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

    configure :development do  
      @@log = Logger.new(STDOUT)
      @@log.level = Logger::DEBUG
      @@log.info("Frank walks onto the stage.")

      ActiveRecord::Base.logger = @@log
      ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database =>  '.FrankData.sqlite3.db'

      @handlers_are_loaded = false
      load_handlers
    end


  # all tempolates within /views/in/ need to use the logged in user template
  # we will also be using Haml to send HTML formatted email but as of this version
  # we will not use mail layout templates.
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
  
end
