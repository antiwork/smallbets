class AddStatsV2Indexes < ActiveRecord::Migration[7.2]
  def change
    # Critical for online users count query (fixes 16.5s bottleneck)
    add_index :memberships, :connected_at,
      if_not_exists: true,
      name: 'index_memberships_on_connected_at'

    # Optimize message queries with composite indexes
    add_index :messages, [:active, :created_at, :creator_id],
      if_not_exists: true,
      name: 'index_messages_on_active_created_at_creator_id'

    add_index :messages, [:active, :room_id, :created_at],
      if_not_exists: true,
      name: 'index_messages_on_active_room_id_created_at'

    # Optimize user lookups for active, non-suspended users
    add_index :users, [:active, :suspended_at],
      if_not_exists: true,
      name: 'index_users_on_active_suspended_at'
  end
end
