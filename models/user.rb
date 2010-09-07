#!usr/bin/ruby
require 'active_record'

class User < ActiveRecord::Base
  def haml_object_ref
    "a_user"
  end
end
