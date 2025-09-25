class AddTwitterOauthToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :twitter_uid, :string
    add_column :users, :twitter_username, :string
    add_index :users, :twitter_uid, unique: true
  end
end