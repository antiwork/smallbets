class AddIndexOnRoomsActiveColumn < ActiveRecord::Migration[7.2]
  def change
    add_index :rooms, :active
  end
end
