class CreateLibraryClassesCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :library_classes_categories, id: false do |t|
      t.references :library_class, null: false, foreign_key: true
      t.references :library_category, null: false, foreign_key: true
    end

    add_index :library_classes_categories, [:library_class_id, :library_category_id], unique: true, name: 'index_library_classes_categories_on_class_and_category'
  end
end
