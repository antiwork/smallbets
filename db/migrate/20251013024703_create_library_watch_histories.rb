class CreateLibraryWatchHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :library_watch_histories do |t|
      t.references :library_session, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true, index: false
      t.integer :played_seconds, null: false, default: 0
      t.datetime :last_watched_at

      t.timestamps
    end

    add_index :library_watch_histories, [ :library_session_id, :user_id ], name: "index_library_watch_histories_on_session_and_user", unique: true
  end
end
