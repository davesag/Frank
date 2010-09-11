#!usr/bin/ruby
require 'active_record'
require 'bcrypt'
require 'logger'

class User < ActiveRecord::Base
  has_many :preferences

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
    
  def set_preference(name,value)
    pref = self.preferences.first(:conditions => {:name => name})
    if pref
      pref.update!(:value => value)
    else
      self.preferences.build(:name => name, :value => value)
    end
  end

  def get_preference(name)
    self.preferences.first(:conditions => {:name => name})
  end

end

# Creating a user.

def create (username, email, password)
  @user = User.new(username)
  @user.email = email
  @user.password = password
  @user.save!
end

def create
  @user = User.create(params[:username], params[:email], params[:password])
end

# Authenticating a user

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

# Checking the existence of a user with this username or email
def username_exists?(username)
  return User.find_by_username(username) != nil
end

def email_exists?(email)
  return User.find_by_email(email) != nil
end

# If a user forgets their password?
# assign them a random one and mail it to them, asking them to change it

def reset_password(email)
  @user = User.find_by_email(email)
  random_password = Array.new(10).map { (65 + rand(58)).chr }.join
  @user.password = random_password
  @user.save!
#  Mailer.create_and_deliver_password_change(@user, random_password)
# commented out mailer for now as I have no Idea what it is or does. 
end

public :login, :reset_password, :email_exists?, :username_exists?
