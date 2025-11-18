class LibraryCatalog
  class << self
    def sections
      LibraryClass.includes(:library_categories, library_sessions: :library_watch_histories).all
    end

    def inertia_props(user:)
      classes = sections
      histories = preload_histories(user:)
      history_by_session_id = histories.index_by(&:library_session_id)

      session_payload_lookup = {}

      sections_payload = classes.map do |library_class|
        categories = library_class.library_categories.map { |category| build_category_payload(category) }

        sessions = library_class.library_sessions.map do |session|
          history = history_by_session_id[session.id]
          payload = build_session_payload(session, categories:, history: history)
          session_payload_lookup[session.id] = payload
          payload
        end

        {
          id: library_class.id,
          slug: library_class.slug,
          title: library_class.title,
          creator: library_class.creator,
          categories: categories,
          sessions: sessions
        }
      end

      continue_watching = histories.reject(&:completed?).filter_map do |history|
        session_payload_lookup[history.library_session_id]
      end

      featured_sessions = LibrarySession
        .featured_ordered
        .includes(:library_watch_histories, library_class: :library_categories)

      featured_payload = featured_sessions.map do |session|
        categories = session.library_class.library_categories.map { |category| build_category_payload(category) }
        history = history_by_session_id[session.id]
        payload = build_session_payload(session, categories:, history: history)
        session_payload_lookup[session.id] = payload
        payload
      end

      {
        sections: sections_payload,
        continueWatching: continue_watching,
        featuredSessions: featured_payload
      }
    end

    private

    def preload_histories(user:)
      return LibraryWatchHistory.none unless user

      LibraryWatchHistory
        .where(user: user)
        .includes(:library_session)
        .order(updated_at: :desc)
    end

    def build_session_payload(session, categories:, history: nil)
      {
        id: session.id,
        title: session.title,
        description: session.description,
        categories: categories,
        padding: session.padding,
        vimeoId: session.vimeo_id,
        vimeoHash: session.vimeo_hash,
        creator: session.library_class.creator,
        playerSrc: session.player_src,
        downloadPath: session.download_path,
        position: session.position,
        watchHistoryPath: routes.library_session_watch_history_path(session),
        watch: build_watch_payload(history)
      }
    end

    def build_watch_payload(history)
      return nil unless history

      {
        playedSeconds: history.played_seconds,
        durationSeconds: history.duration_seconds,
        lastWatchedAt: history.last_watched_at&.iso8601,
        completed: history.completed?
      }
    end

    def build_category_payload(category)
      {
        id: category.id,
        name: category.name,
        slug: category.slug
      }
    end

    def routes
      Rails.application.routes.url_helpers
    end
  end
end
