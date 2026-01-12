class AddTwitterOAuthToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :twitter_uid, :string
    add_column :users, :twitter_oauth_token, :text
    add_column :users, :twitter_oauth_refresh_token, :text
    add_column :users, :twitter_screen_name, :string
    add_column :users, :twitter_profile_image, :string
    add_column :users, :twitter_connected_at, :datetime
    
    add_index :users, :twitter_uid, unique: true
  end
end
