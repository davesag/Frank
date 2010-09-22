#!usr/bin/ruby

class AddValidationTokenToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :validation_token, :string, :default => "", :null => false
    add_index :users, :validation_token, :unique => true
  end
  
  def self.down
    remove_index :users, :validation_token
    remove_column :users, :validation_token
  end
end
