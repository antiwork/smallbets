class LibraryCategory < ApplicationRecord
  has_and_belongs_to_many :library_classes, join_table: :library_classes_categories

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
end
