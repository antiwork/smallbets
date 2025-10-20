module API
  module Videos
    class ThumbnailsController < AuthenticatedController
      before_action :ensure_json_response
      allow_unauthenticated_access only: :index

      def index
        ids = normalized_ids
        if ids.empty?
          render json: {}
          return
        end

        # Serve cached thumbnails immediately; enqueue background fetch for misses.
        cached = Vimeo::ThumbnailFetcher.read_cached_many(ids)
        missing = ids.map(&:to_s) - cached.keys
        Vimeo::ThumbnailFetcher.enqueue_many(missing)

        Rails.logger.info(
          "api.videos.thumbnails.request" => {
            requested: ids.size,
            cached: cached.size,
            enqueued: missing.size,
            ids: ids
          }
        )
        thumbnails = cached

        if thumbnails.blank?
          response.headers["Cache-Control"] = "public, max-age=300"
          render json: {}
          return
        end

        # Normalize order to make ETag stable
        ordered = thumbnails.sort.to_h
        # Set cache headers and respond with 304 when fresh
        expires_in 1.hour, public: true, "stale-while-revalidate" => 86400
        if stale?(strong_etag: ordered)
          render json: ordered
        end
      rescue => e
        Rails.logger.warn("api.videos.thumbnails.error" => { ids: ids, error: e.class.name, message: e.message })
        response.headers["Cache-Control"] = "public, max-age=120"
        render json: {}
      end

      private

      def normalized_ids
        raw = params[:ids]
        return [] unless raw

        Array(raw)
          .flat_map { |value| value.to_s.split(",") }
          .map(&:strip)
          .reject(&:blank?)
          .uniq
      end

      def ensure_json_response
        request.format = :json
      end
    end
  end
end

