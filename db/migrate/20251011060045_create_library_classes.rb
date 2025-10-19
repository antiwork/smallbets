class CreateLibraryClasses < ActiveRecord::Migration[7.2]
  def change
    create_table :library_classes do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.string :creator, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :library_classes, :slug, unique: true
    add_index :library_classes, :position
  end
end
