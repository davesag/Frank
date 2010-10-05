#!usr/bin/ruby

require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/r18n'
require 'pony'

module Sinatra
  module EmailHelpers

    #################       UTILITY METHODS FOR SENDING USER EMAILS     ###########################

  # utility method to actually send the email. uses a haml template for HTML email and erb for plain text.
    def send_email_to_user(user, subject, body_template, template_locals)   
      if 'true' == user.get_preference("HTML_EMAIL").value
        email_body = haml(body_template, :locals => template_locals )
        type = 'text/html'
      else
        email_body = erb(body_template, :locals => template_locals)
        type = 'text/plain'
      end

      if options.environment == :development                          # assumed to be on your local machine
        Pony.mail :to => user.email, :via =>:sendmail,
          :from => "frank_test@davesag.com", :subject => subject,
          :headers => { 'Content-Type' => type }, :body => email_body
#        @@log.debug("Email sent via SendMail in local Developer environment.")
      elsif options.environment == :production                         # assumed to be Heroku
        Pony.mail :to => user.email, :from => "frank_demo@davesag.com", :subject => subject,
          :headers => { 'Content-Type' => type }, :body => email_body, :via => :smtp,
          :via_options => {
            :address => 'smtp.sendgrid.net',
            :port => 25,
            :authentication => :plain,
            :user_name => ENV['SENDGRID_USERNAME'],
            :password => ENV['SENDGRID_PASSWORD'],
            :domain => ENV['SENDGRID_DOMAIN'] }
#          @@log.debug("Email sent via SMTP in production environment on Heroku.")
      else
#        @@log.debug("TESTING so I constructed, but did NOT actually send, an email to #{user.email} with subject '#{subject}' using template '#{body_template}'.")
      end
    end

  # notify the user with that email if new registration tries to use your email
    def notify_user_of_registration_overlap_attempt!(email,supplied_name)
      user = User.find_by_email(email)
      template_locals = { :user => user, :supplied_name => supplied_name}
      send_email_to_user(user, t.u.mail_registration_email_overlap_subject, :'mail/email_warning', template_locals)
    end

  # notify the user with that email if user tries to change their email to yours
    def notify_user_of_email_change_overlap_attempt!(email,supplied_name)
      user = User.find_by_email(email)
      template_locals = { :user => user, :supplied_name => supplied_name}
      send_email_to_user(user, t.u.mail_edit_email_overlap_subject, :'mail/email_change_warning', template_locals)
    end

  # generate a confirmation url and email and send it to the user.
    def send_registration_confirmation_to(user)
      token_link = "http://" + request.host_with_port + "/validate/" + user.validation_token
      template_locals = { :user => user, :token_url => token_link}
      send_email_to_user(user, t.u.mail_registration_confirmation_subject, :'mail/new_registration', template_locals)
    end

    def send_email_update_confirmation_to(user)
      token_link = "http://" + request.host_with_port + "/validate/" + user.validation_token
      template_locals = { :user => user, :token_url => token_link}
      send_email_to_user(user, t.u.mail_edit_email_confirmation_subject, :'mail/change_email', template_locals)
    end

    def send_password_reset_to(user)
      token_link = "http://" + request.host_with_port + "/reset_password/" + user.validation_token
      template_locals = { :user => user, :token_url => token_link}
      send_email_to_user(user, t.u.mail_password_reset_subject, :'mail/reset_password', template_locals)
    end 


  end

  helpers EmailHelpers

end
