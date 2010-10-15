#!usr/bin/ruby

require 'bundler/setup'
require 'sinatra/base'

module Sinatra

  # this is a first stab at a system to genecise form handling.
  # the idea is that in an MVC system there needs to be some sort of container object in the session
  # that holds a map of the form to be displayed, with meta information about the form elements
  # such that a smart chunk of haml script can build the form automagically.
  module FormHelpers

    def clear_form
      session[:active_form] = []
      session[:active_form_changed?] = false
      session[:active_form_errors] = Hash.new
    end

    def update_form
      session[:active_form_changed?] = false
      session[:active_form_errors] = Hash.new
      for field in active_form do
        old_value = field[:value]
        new_value = params[:"#{field[:name]}"]
        error = false
        # do validations
        if field[:required] && new_value ==  ''
          add_error(field[:name], "Required field was missing")
          error = true
        elsif field[:validation] != nil
          # we only support email validation right now
          fv = field[:validation]
          if fv == 'email'
            if !validate_email(new_value)
              add_error(field[:name], "Not a valid email")
              error = true
            end
          else
            # some other validation
          end
        end

        if !error
          # update the field value
          field[:value] = new_value unless field[:type] == 'password' && new_value == ''
        
          # set the changed flag
          session[:active_form_changed?] ||= old_value != new_value
        end
      end
    end

    def form_changed?
      return session[:active_form_changed?]
    end

    # return the current active container
    def active_form
      if session[:active_form] == nil
        clear_form
      end
      return session[:active_form]
    end

    # return the current active container
    def active_errors
      return session[:active_form_errors]
    end

    # validation => { :size => ">3", allowed =>"[a..z]"}}    
    def add_field(name, value, type, required, validation, label_text, options )
      f = active_form
      f << { :name => name, :value => value, :type => type, :required => required, :validation => validation, :label_text => label_text, :options => options }
      return f
    end

    def add_error(name, message)
      e = active_errors
      e[name] = message
      return e
    end

    def error_message(name)
      return active_errors[name]
    end

    def field_okay?(name)
      if !active_errors.empty?
        return false unless active_errors[name] == nil
      end
      return true
    end

    def form_okay?
      return active_errors.empty?
    end

    def build_validation_call(field)
      onchange = field[:required] ? "require(this);" : ''
      if nil != field[:validation]
        onchange += " validate(this)"
      end
      return onchange
    end

    # validations
    
    def validate_email(email)
      return email.include? '@'
    end

  end

  helpers FormHelpers

end
