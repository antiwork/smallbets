class EmailDigestEntry < ApplicationRecord
  belongs_to :room

  validates :digest_date, :position, presence: true

  scope :previously_sent_room_ids, -> { distinct.pluck(:room_id) }
end
