class AddFeaturedToLibrarySessions < ActiveRecord::Migration[7.2]
  def change
    change_table :library_sessions, bulk: true do |t|
      t.boolean :featured, null: false, default: false
      t.integer :featured_position, null: false, default: 0
    end

    add_index :library_sessions, :featured
    add_index :library_sessions, :featured_position
  end
end


