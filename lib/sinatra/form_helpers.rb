#!usr/bin/ruby

require 'bundler/setup'
require 'sinatra/base'

module Sinatra

  # this is a first stab at a system to genecise form handling.
  # the idea is that in an MVC system there needs to be some sort of container object in the session
  # that holds a map of the form to be displayed, with meta information about the form elements
  # such that a smart chunk of haml script can build the form automagically.
  # TODO: i18n the literal strings
  module FormHelpers

    # reset the form and its associated error fields and flags.
    def open_form
      session[:active_form] = []
      session[:active_form_changed?] = false
      session[:active_form_errors] = Hash.new
      session[:active_form_error_flags] = Hash.new
    end

    # compare what is in the income request params with what is in the form fields,
    # test for any required fields and run any simple validations.
    # and if the field is then okay move the param into the field.
    def update_form
      if !active_form.empty?
        session[:active_form_changed?] = false
        session[:active_form_errors] = Hash.new
        session[:active_form_error_flags] = Hash.new
        for field in active_form do
          old_value = field[:value]
          new_value = params[:"#{field[:name]}"]
          error = false
#          if old_value != new_value
#            require 'ruby-debug'
#            debugger
#          end
          # do validations
          if field[:required] && new_value ==  '' && field[:validation] != 'new_password'
            add_error(field[:name], t.u.error_required_field, 'missing')
            error = true
          elsif field[:validation] != nil && new_value != old_value   # only validate fields that have changed.
            # we support email[, unique], username[, unique], password or username_or_email validation
            fv = field[:validation]
            case
            when fv.start_with?('email')
              if !validate_email(new_value)
                add_error(field[:name], t.u.error_invalid_email(new_value), 'invalid')
                error = true
              end
              if fv.end_with?('unique') && !validate_email_is_unique(new_value)
                add_error(field[:name], t.u.error_email_clash(new_value), 'unique')
                error = true
              end
            when fv.start_with?('username') && fv != 'username_or_email'
              if !validate_username(new_value)
                add_error(field[:name], t.u.error_invalid_username, 'invalid')
                error = true
              end
              if fv.end_with?('unique') && !validate_username_is_unique(new_value)
                add_error(field[:name], t.u.error_username_clash(new_value), 'unique')
                error = true
              end
            when fv.start_with?('role')
              if !validate_role_name(new_value)
                add_error(field[:name], t.u.error_invalid_role, 'invalid')
                error = true
              end
              if fv.end_with?('unique') && !validate_role_name_is_unique(new_value)
                add_error(field[:name], t.u.error_dupe_role_name(new_value), 'unique')
                error = true
              end
            when fv == 'password'
              if !validate_password(new_value)
                add_error(field[:name], t.u.error_invalid_password, 'invalid')
                error = true
              end            
            when fv == 'new_password'
              return true unless new_value != ''
              if !validate_password(new_value)
                add_error(field[:name], t.u.error_invalid_new_password, 'invalid')
                error = true
              end
            when fv == 'username_or_email'
              if !(validate_username(new_value) || validate_email(new_value))
                add_error(field[:name], t.u.error_invalid_username_or_email, 'invalid')
                error = true
              end            
            else
              # we don't recognise any other validations right now.
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
    end

    def close_form
      open_form           # does the same thing for now.
    end

    def form_changed?
      return session[:active_form_changed?]
    end

    # return the current active form container
    def active_form
      open_form unless session[:active_form]
      return session[:active_form]
    end

    # return the current active error container
    def active_errors
      return session[:active_form_errors]
    end

    # return the current active error container
    def active_error_flags
      return session[:active_form_error_flags]
    end

    # validation => 'email', or 'username', or 'password', or 'usernameoremail' etc
    def add_field(name, value, type, required, validation, label_text, options = nil, size = nil )
      f = active_form
      f << { :name => name, :value => value, :type => type, :required => required, :validation => validation, :label_text => label_text, :options => options, :size => size }
      return f
    end

    def add_error(name, message, flag)
      active_errors[name] = message
      active_error_flags[name] = flag
      return active_errors
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
      return onchange == '' ? nil : onchange
    end

    # validations
    
    # a valid email has a '@' in it.
    def validate_email(email)
      return false unless email != nil
      return email.include? '@'
    end

    # check to see if the email already exists
    def validate_email_is_unique(email)
      return false unless email != nil
      return !User.email_exists?(email)
    end

    # a valid username has no whitespace and is less than 20 characters
    def validate_username(username)
      return false unless username != nil
      if username.length > 19
        return false
      end
      stripped = username.gsub(/[ \&\=\+\-\?]/,'')
      return username == stripped
    end

    # check to see if the username already exists
    def validate_username_is_unique(username)
      return false unless username != nil
      return !User.username_exists?(username)
    end

    #a valid password is longer than 3 characters and less than 20 characters
    def validate_password(password)
      return false unless password != nil
      if password.length < 4 || password.length > 19
        return false
      end
      return true
    end

    # a valid role name has no whitespace and is less than 20 characters
    def validate_role_name(rolename)
      return false unless rolename != nil
      if rolename.length > 19
        return false
      end
      stripped = rolename.gsub(/[ &=+-?]/,'')
      return rolename == stripped
    end

    # check to see if the username already exists
    def validate_role_name_is_unique(rolename)
      return false unless rolename != nil
      return Role.find_by_name(rolename) == nil
    end

    # specific form field configurations
    
    def prep_login_form(default_name)
      open_form
      add_field('username', default_name, 'text', "required", 'username_or_email', t.labels.username_label )
      add_field('password', '', 'password', "required", 'password', t.labels.password_label )
    end

    def prep_registration_form
      open_form
      add_field('email', '', 'text', true, 'email, unique', t.labels.choose_email_label )
      add_field('username', '', 'text', true, 'username, unique', t.labels.choose_username_label )
      add_field('password', '', 'password', true, 'password', t.labels.choose_password_label )
      add_field('locale', i18n.locale, 'select', false, nil, t.labels.choose_language_label, language_options )
      add_field('terms', 'true', "select", false, nil, t.labels.read_and_agree_label,
        [{ :value => 'true', :text => t.labels.option_terms_yes}, { :value => 'false', :text => t.labels.option_terms_no }] )
    end

  end

  helpers FormHelpers

end
