class FeedCard < ApplicationRecord
  self.table_name = "feed_cards"
  self.inheritance_column = :_type_disabled

  belongs_to :room
  belongs_to :promoted_by_user, class_name: "User", optional: true
  belongs_to :preview_message, class_name: "Message", optional: true

  validates :title, presence: true
  validates :type, presence: true, inclusion: { in: %w[automated promoted] }

  scope :ordered, -> { order(created_at: :desc) }
  scope :automated, -> { where(type: "automated") }
  scope :promoted, -> { where(type: "promoted") }

  def automated?
    type == "automated"
  end

  def promoted?
    type == "promoted"
  end
end
