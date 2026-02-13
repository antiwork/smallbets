class AddExcludeFromDigestToRooms < ActiveRecord::Migration[7.2]
  def change
    add_column :rooms, :exclude_from_digest, :boolean, default: false, null: false
  end
end
