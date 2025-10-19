class CreateLibraryCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :library_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :library_categories, :slug, unique: true
  end
end
