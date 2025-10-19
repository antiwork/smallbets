class CreateLibrarySessions < ActiveRecord::Migration[7.2]
  def change
    create_table :library_sessions do |t|
      t.references :library_class, null: false, foreign_key: true
      t.string :vimeo_id, null: false
      t.string :vimeo_hash
      t.decimal :padding, precision: 5, scale: 2, null: false, default: 56.25
      t.string :quality
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :library_sessions, :vimeo_id
    add_index :library_sessions, :position
  end
end
