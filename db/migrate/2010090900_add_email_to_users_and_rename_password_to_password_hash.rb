#!usr/bin/ruby

class AddEmailToUsersAndRenamePasswordToPasswordHash < ActiveRecord::Migration
  def self.up
    add_column :users, :email, :string, :default => "", :null => false
    rename_column :users, :password, :password_hash
  end
  
  def self.down
    rename_column :users, :password_hash, :password
    remove_column :users, :email
  end
end
