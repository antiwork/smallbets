class AddIndexToRoomsType < ActiveRecord::Migration[7.2]
  def change
    add_index :rooms, :type, name: 'index_rooms_on_type'
  end
end
