#!usr/bin/ruby
require 'active_record'

class Preference < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :name, :scope => :user_id
  
  def haml_object_ref
    "a_preference"
  end  
end

# Creating the preference

def create (name,value)
  @pref = Preference.new(name)
  @pref.value = value
  @pref.save!
end

def create
  @pref = Preference.create(params[:name], params[:value])
end
