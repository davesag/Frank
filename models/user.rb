#!usr/bin/ruby
require 'active_record'
require 'bcrypt'
require 'logger'

class User < ActiveRecord::Base
  has_many :preferences
  validates_uniqueness_of :username
  validates_uniqueness_of :email
  validates_uniqueness_of :validation_token
  before_create :assign_validation_token
  
  @@CHARS = ("a".."z").to_a + ("A".."Z").to_a
  
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
     self.generate_token!
     puts "Validation URL is http://localhost:9292/validate/" + self.validation_token
   end
 end

 def generate_token!
   n = Digest::MD5.hexdigest(self.username).hex
   token_array = []
   while n > 0
     token_array << @@CHARS[n.divmod(@@CHARS.size)[1]]
     n = n.divmod(@@CHARS.size)[0]
   end
   self.validation_token = token_array.to_s
 end

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
