class AddOauthToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    
    add_index :users, [:provider, :uid], unique: true
    add_index :users, :uid
  end
end
