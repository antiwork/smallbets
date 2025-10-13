module Library
  class WatchHistoryUpdater
    include ActiveModel::Model

    attr_reader :history, :payload

    validates :played_seconds, numericality: { greater_than_or_equal_to: 0 }
    validates :duration_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    def initialize(history:, payload: {})
      @history = history
      @payload = payload.symbolize_keys
      super()
    end

    def apply
      return false unless valid?

      history.played_seconds = played_seconds
      history.duration_seconds = duration_seconds unless duration_seconds.nil?
      history.completed = completed? unless completed?.nil?
      history.last_watched_at = Time.current

      history.save
    end

    def error_message
      errors.full_messages.to_sentence.presence || "Unable to update watch history"
    end

    def played_seconds
      payload[:played_seconds]
    end

    def duration_seconds
      payload[:duration_seconds]
    end

    def completed?
      payload[:completed]
    end
  end
end

