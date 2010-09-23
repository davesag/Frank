#!usr/bin/ruby
require 'active_record'

class Preference < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :name, :scope => :user_id
  
  def haml_object_ref
    "a_preference"
  end  
end
