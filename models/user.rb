#!usr/bin/ruby
require 'active_record'
require 'bcrypt'
require 'logger'

class User < ActiveRecord::Base
  has_many :preferences
  has_and_belongs_to_many :roles
  validates_uniqueness_of :username
  validates_uniqueness_of :email
  validates_uniqueness_of :validation_token
  before_create :assign_validation_token
  
  @@CHARS = ("a".."z").to_a + ("A".."Z").to_a
  
#  def haml_object_ref
#    "a_user"
#  end

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
      pref.update_attribute :value, value
    else
      self.preferences.build(:name => name, :value => value)
    end
  end

  def get_preference(name)
    self.preferences.first(:conditions => {:name => name})
  end

  # make sure we also create the validation_token.
  def assign_validation_token
    if self.validation_token == nil || self.validation_token = ""
      self.validation_token = self.generate_token(self.username)
    end
  end

  def generate_token(seed)
    n = Digest::MD5.hexdigest(seed).hex
    token_array = []
    while n > 0
      token_array << @@CHARS[n.divmod(@@CHARS.size)[1]]
      n = n.divmod(@@CHARS.size)[0]
    end
    return token_array.to_s
  end

  def shuffle_token!
    random_seed = Array.new(9 + rand(6)).map { (65 + rand(58)).chr }.join
    self.validation_token = self.generate_token(random_seed)
  end

# def remove_role(name)
#   role = self.roles.first(:conditions => {:name => name})
#   if role
#     self.roles.remove(:name => name)
#   else
#     # all good, user doesn't have this role, should this throw a warning?
#   end
# end

end

# Authenticating a user

def login(name_or_email, plain_password)
  if name_or_email.include?("@")
    @user = User.find_by_email(name_or_email)
  else
    @user = User.find_by_username(name_or_email)
  end
  if @user == nil || @user.password != plain_password || !@user.validated
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

def has_role?(name)
  role = Role.find_by_name(name)
  # does the role even exist?
  return false unless role != nil
  # role exists, is the user in it?
  return self.roles.first(:conditions => {:name => name}) != nil
end

def add_role(name)
  role = Role.find_by_name(name)
  if role != nil
    # role exists
    myrole = self.roles.find_by_name(name)
    if myrole == nil  # add this role as we don't already have it.
      self.roles << role
    end
  else
    # oh dear, role #{name} doesn't exist.
    # do nothing or return an error?  throw an exception?  What is the Ruby way?
    puts "There is no such Role as '#{name}'"
  end
end

public :login, :email_exists?, :username_exists?, :has_role?, :add_role
