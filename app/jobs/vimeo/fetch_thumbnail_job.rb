module Vimeo
  class FetchThumbnailJob < ApplicationJob
    queue_as :default

    def perform(video_id)
      begin
        Vimeo::ThumbnailFetcher.fetch(video_id)
      rescue => e
        Rails.logger.warn("vimeo.fetch_thumbnail_job.error" => { video_id: video_id, error: e.class.name, message: e.message })
      end
    end
  end
end


