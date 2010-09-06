#!usr/bin/ruby

class CrazyUser < ActiveRecord::Base
  def haml_object_ref
    "a_crazy_user"
  end
end
