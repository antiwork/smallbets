module Vimeo
  class WarmThumbnailsJob < ApplicationJob
    queue_as :default

    # Warms cache for provided video_ids or discovers from LibrarySession
    def perform(video_ids: nil, limit: nil)
      return if Vimeo::ThumbnailFetcher.access_token.blank?

      ids = Array(video_ids).compact_blank.map(&:to_s)
      if ids.empty?
        ids = LibrarySession.order(:position).pluck(:vimeo_id).compact_blank.map(&:to_s)
      end
      ids = ids.first(limit) if limit.present?

      cached = ThumbnailFetcher.read_cached_many(ids)
      stale_or_missing = ids - cached.keys

      Rails.logger.info(
        "vimeo.warm_thumbnails.enqueuing" => {
          discovered: ids.size,
          cached: cached.size,
          enqueuing: stale_or_missing.size
        }
      )

      ThumbnailFetcher.enqueue_many(stale_or_missing)
    end
  end
end
