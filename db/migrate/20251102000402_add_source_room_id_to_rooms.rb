class AddSourceRoomIdToRooms < ActiveRecord::Migration[7.2]
  def change
    add_reference :rooms, :source_room, null: true, foreign_key: { to_table: :rooms }
  end
end
