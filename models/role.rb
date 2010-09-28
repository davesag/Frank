#!usr/bin/ruby
require 'active_record'

class Role < ActiveRecord::Base
  has_and_belongs_to_many :users
  validates_uniqueness_of :name

  @@BLESSED = ['admin', 'superuser']

  
#  def haml_object_ref
#    "a_role"
#  end  
end
