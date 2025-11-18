class LibraryWatchHistory < ApplicationRecord
  belongs_to :library_session
  belongs_to :user

  validates :played_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :duration_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def completed?
    completed
  end

  def mark_completed!
    update!(completed: true, last_watched_at: Time.current)
  end
end

