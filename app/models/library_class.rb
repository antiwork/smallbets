class LibraryClass < ApplicationRecord
  has_many :library_sessions, -> { order(position: :asc) }, dependent: :destroy
  has_and_belongs_to_many :library_categories, join_table: :library_classes_categories

  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true
  validates :creator, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  default_scope { order(position: :asc) }
end
