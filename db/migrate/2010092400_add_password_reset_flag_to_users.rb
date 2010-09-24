#!usr/bin/ruby

class AddPasswordResetFlagToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :password_reset, :boolean, :default => false, :null => false
  end
  
  def self.down
    remove_column :users, :password_reset
  end
end
