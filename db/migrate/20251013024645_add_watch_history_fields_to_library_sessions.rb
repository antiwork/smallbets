class AddWatchHistoryFieldsToLibrarySessions < ActiveRecord::Migration[7.2]
  def change
    add_column :library_sessions, :played_seconds, :integer, default: 0, null: false
    add_column :library_sessions, :last_watched_at, :datetime
  end
end
