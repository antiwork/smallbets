class CreateLiveEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :live_events do |t|
      t.string :title, null: false
      t.string :url, null: false
      t.datetime :target_time, null: false
      t.integer :duration_hours, null: false, default: 2
      t.integer :show_early_hours, null: false, default: 24
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :live_events, :active
    add_index :live_events, :target_time
  end
end
