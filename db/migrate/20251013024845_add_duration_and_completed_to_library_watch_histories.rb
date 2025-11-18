class AddDurationAndCompletedToLibraryWatchHistories < ActiveRecord::Migration[7.2]
  def change
    add_column :library_watch_histories, :duration_seconds, :integer
    add_column :library_watch_histories, :completed, :boolean, default: false, null: false
  end
end
