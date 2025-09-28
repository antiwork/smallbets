class WarmVideoMetadataJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting video metadata cache warming..."
    
    LibraryCatalog.sections.each do |section|
      section.videos.each do |video|
        begin
          # This will trigger the API call and cache the result
          video.metadata
          Rails.logger.debug "Cached metadata for video #{video.vimeo_id}"
        rescue => e
          Rails.logger.error "Failed to cache metadata for video #{video.vimeo_id}: #{e.message}"
        end
      end
    end
    
    # Also cache the total stats
    LibraryCatalog.total_stats
    
    Rails.logger.info "Completed video metadata cache warming"
  end
end
