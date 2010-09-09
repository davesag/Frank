#!usr/bin/ruby
require 'active_record'
require 'bcrypt'
require 'logger'

class User < ActiveRecord::Base
  def haml_object_ref
    "a_user"
  end

  # users.password_hash in the database is a :string
  include BCrypt
  
  def password
    @password ||= Password.new(password_hash)
  end

  def password=(new_password)
    @password = Password.create(new_password)
    self.password_hash = @password
  end
  
end

# === Creating an account

def create
  @user = User.new(params[:username])
  @user.email = params[:email]
  @user.password = params[:password]
  @user.save!
end

# === Authenticating a user

def login(name_or_email, plain_password)
  if name_or_email.include?("@")
    @user = User.find_by_email(name_or_email)
  else
    @user = User.find_by_username(name_or_email)
  end
  if @user == nil || @user.password != plain_password
    @user = nil
  end
  return @user
end

#=== If a user forgets their password?

# assign them a random one and mail it to them, asking them to change it
def reset_password(email)
  @user = User.find_by_email(email)
  random_password = Array.new(10).map { (65 + rand(58)).chr }.join
  @user.password = random_password
  @user.save!
#  Mailer.create_and_deliver_password_change(@user, random_password)
end

public :login, :reset_password
