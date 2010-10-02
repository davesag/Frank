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
  before_save :downcase!

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

############### things that happen before create ########################

  # make sure we also create a unique validation_token.
  def assign_validation_token
    if self.validation_token == nil || self.validation_token = ""
      self.validation_token = self.generate_token(self.username)
    end
  end

  def generate_token(seed)
    seed = random_seed unless seed != nil
    n = Digest::MD5.hexdigest(seed).hex
    token_array = []
    while n > 0
      token_array << @@CHARS[n.divmod(@@CHARS.size)[1]]
      n = n.divmod(@@CHARS.size)[0]
    end
    return token_array.to_s
  end

  def shuffle_token!
    self.validation_token = self.generate_token(random_seed)
  end

  def random_seed
    return Array.new(9 + rand(6)).map { (65 + rand(58)).chr }.join
  end

  ############### things that happen before save ########################
  def downcase!
    self.username.downcase!
    self.email.downcase!
  end

  ######################### users have roles ############################

  # does this use have the named role?
  def has_role?(name)
    role = Role.find_by_name(name)
    # does the role even exist?
    return false unless role != nil
    # role exists, is the user in it?
    return self.roles.first(:conditions => {:name => name}) != nil
  end

  # add the named role.
  def add_role(name)
    role = Role.find_by_name(name)
    if role != nil
      # role exists
      self.roles << role unless self.roles.include?(role)
    end
  end

#  we don't need this because when we set the user's roles again it's easier to call replace_roles
#  # remove the named role.
#  def remove_role(name)
#    role = Role.find_by_name(name)
#    if role != nil
#      # role exists
#      self.roles.delete(role)
#    end
#  end

  # replaces the users roles with roles from the supplied array of role names.
  def replace_roles(role_names)
    removals = []
    for role in self.roles do
      if !role_names.include?(role.name)
        removals << role 
      else
        role_names.delete(role.name)
      end
    end
    self.roles = self.roles - removals
    # all that's left in role_names now is the names of roles to add
    for role_name in role_names do
      add_role(role_name) unless role_name == ''
    end
  end

  # some users can edit other users according to their roles
  # a superuser can edit anyone
  # an admin can edit anyone not a superuser or admin
  def can_edit_user?(user)
    if self.has_role?('superuser')
      return true
    elsif !self.has_role?('admin')
      return false
    end
    return !(user.has_role?('superuser') || user.has_role?('admin'))
  end

end

######################### CLASS LEVEL METHODS ################################
# defines the authentication rules.
# in this case we match against either a username or supplied plaintext password using logic defined
# by overriding the .password= method.  In the db we store only the password_hash
# usernames and emails will always be stored as lower case so we downcase! the name/email before searching.
def login(name_or_email, plain_password)
  name_or_email.downcase!                 # 
  if name_or_email.include?("@")
    user = User.find_by_email(name_or_email)
  else
    user = User.find_by_username(name_or_email)
  end
  if user == nil || user.password != plain_password || !user.validated
    user = nil
  end
  return user
end

# TODO: there is probably a better way to do this.
def username_exists?(username)
  return User.find_by_username(username.downcase) != nil
end

# TODO: there is probably a better way to do this.
def email_exists?(email)
  return User.find_by_email(email.downcase) != nil
end

public :login, :email_exists?, :username_exists?
