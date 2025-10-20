namespace :thumbnails do
  desc "Warm Vimeo thumbnails cache (optionally with LIMIT=n)"
  task warm: :environment do
    limit = ENV["LIMIT"].presence&.to_i
    Vimeo::WarmThumbnailsJob.perform_later(video_ids: nil, limit: limit)
    puts "Enqueued Vimeo::WarmThumbnailsJob (limit=#{limit || 'none'})"
  end
end
