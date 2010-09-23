#!usr/bin/ruby

class CreateRolesTable < ActiveRecord::Migration
  def self.up
    create_table :roles do |t|
      t.column :name, :string, :null => false
    end
  end
  
  def self.down
    drop_table :roles
  end
end

