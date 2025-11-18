class LiveEvent < ApplicationRecord
  validates :title, :url, :target_time, :duration_hours, :show_early_hours, presence: true
  validates :duration_hours, :show_early_hours, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :displayable, -> {
    active.where("target_time >= ?", Time.current - duration_hours.hours)
  }

  def self.current
    active
      .where("target_time >= ?", Time.current)
      .order(:target_time)
      .first ||
    active
      .where("target_time < ? AND target_time >= ?", Time.current, Time.current - 7.days)
      .where("datetime(target_time, '+' || duration_hours || ' hours') >= datetime('now')")
      .order(target_time: :desc)
      .first
  end

  def expired?
    end_time < Time.current
  end

  def end_time
    target_time + duration_hours.hours
  end
end
