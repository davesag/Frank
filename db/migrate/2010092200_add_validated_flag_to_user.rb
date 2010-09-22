#!usr/bin/ruby

class AddValidatedFlagToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :validated, :boolean, :default => false, :null => false
  end
  
  def self.down
    remove_column :users, :validated
  end
end
