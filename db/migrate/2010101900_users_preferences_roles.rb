#!usr/bin/ruby

class UsersPreferencesRoles < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.column :username, :string, :null => false
      t.column :password_hash, :string, :null => false
      t.column :email, :string, :null => false
      t.column :locale, :string, :default => 'en', :null => false
      t.column :validation_token, :string, :default => '', :null => false
      t.column :validated, :boolean, :default => false, :null => false
      t.column :password_reset, :boolean, :default => false, :null => false
    end

    # add an index for the email, username, and validation_token fields
    # as they are used to lookup the user.
    add_index :users, :username, :unique => true
    add_index :users, :email, :unique => true
    add_index :users, :validation_token, :unique => true

    # add a table of Preferences for each user, being a simple name, value pair.
    create_table :preferences do |t|
      t.integer :user_id              # preference belongs_to :user in models/preference.rb
                                      # user has_many :preferences in models/user.rb
      t.string :name, :null => false
      t.string :value
    end

    # index the prefs table by name
    add_index :preferences, :name, :unique => false

    create_table :roles do |t|
      t.column :name, :string, :null => false
    end

    add_index :roles, :name, :unique => true

    create_table :roles_users, :id => false do |t|
      t.integer :user_id
      t.integer :role_id
    end

  end

  def self.down
  	drop_table :roles_users
		drop_table :roles
  	drop_table :preferences
    drop_table :users
  end
end
