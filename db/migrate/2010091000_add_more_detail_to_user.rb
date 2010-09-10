#!usr/bin/ruby

class AddMoreDetailToUser < ActiveRecord::Migration
  def self.up
    # add an index for the email and username fields
    # as they are used to lookup the user.
    add_index :users, :username, :unique => true
    add_index :users, :email, :unique => true

    # add a table of Preferences for each user, being a simple name, value pair.
    create_table :preferences do |t|
      t.integer :user_id              # preference belongs_to :user in models/preference.rb
                                      # user has_many :preferences in models/user.rb
      t.string :name, :null => false
      t.string :value
    end

    # index the prefs table by name
    add_index :preferences, :name, :unique => false
    
  end
  
  def self.down
    remove_index :preferences, :name
    drop_table :preferences
    remove_index :users, :email
    remove_index :users, :username
  end
end
