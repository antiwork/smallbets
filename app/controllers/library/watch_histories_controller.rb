module Library
  class WatchHistoriesController < AuthenticatedController
    protect_from_forgery with: :exception

    def create
      history = find_or_initialize_history
      updater = Library::WatchHistoryUpdater.new(history: history, payload: watch_params)

      if updater.apply
        render json: serialize_history(history), status: :created
      else
        render json: { error: updater.error_message }, status: :unprocessable_entity
      end
    end

    def update
      history = find_or_initialize_history
      updater = Library::WatchHistoryUpdater.new(history: history, payload: watch_params)

      if updater.apply
        render json: serialize_history(history)
      else
        render json: { error: updater.error_message }, status: :unprocessable_entity
      end
    end

    private

    def find_or_initialize_history
      session = LibrarySession.find(params[:library_session_id])
      session.library_watch_histories.find_or_initialize_by(user: Current.user)
    end

    def watch_params
      raw = params.require(:watch)
        .permit(:played_seconds, :duration_seconds, :completed, :playedSeconds, :durationSeconds)
        .to_h

      played_seconds = raw.delete("played_seconds")
      camel_played_seconds = raw.delete("playedSeconds")
      played_seconds = camel_played_seconds if played_seconds.blank? && camel_played_seconds.present?

      duration_seconds = raw.delete("duration_seconds")
      camel_duration_seconds = raw.delete("durationSeconds")
      duration_seconds = camel_duration_seconds if duration_seconds.blank? && camel_duration_seconds.present?

      result = {}

      unless played_seconds.nil?
        normalized_played = normalize_seconds(played_seconds)
        result[:played_seconds] = normalized_played unless normalized_played.nil?
      end

      unless duration_seconds.nil?
        normalized_duration = normalize_seconds(duration_seconds)
        result[:duration_seconds] = normalized_duration unless normalized_duration.nil?
      end

      if raw.key?("completed")
        result[:completed] = ActiveModel::Type::Boolean.new.cast(raw["completed"])
      end

      result
    end

    def normalize_seconds(value)
      return value if value.is_a?(Integer)
      return value.to_i if value.is_a?(Float)
      return nil if value.respond_to?(:blank?) && value.blank?

      number = Float(value)
      number.to_i
    rescue ArgumentError, TypeError
      nil
    end

    def serialize_history(history)
      {
        watch: {
          playedSeconds: history.played_seconds,
          durationSeconds: history.duration_seconds,
          lastWatchedAt: history.last_watched_at&.iso8601,
          completed: history.completed?
        }
      }
    end
  end
end
