module Vimeo
  module Library
    API_ROOT = "https://api.vimeo.com".freeze

    module_function

    def fetch_download_url(video_id, preferred_quality = nil)
      return if video_id.blank?

      download = select_download(fetch_downloads(video_id), preferred_quality)
      download&.dig(:link)
    end

    def select_download(downloads, preferred_quality)
      return if downloads.blank?

      if preferred_quality.present?
        downloads.find { |entry| entry[:quality] == preferred_quality }
      end || downloads.first
    end

    def fetch_video_metadata(video_id)
      Rails.cache.fetch("vimeo_metadata_#{video_id}", expires_in: 1.hour) do
        response = http_client.get("/videos/#{video_id}") do |req|
          req.params[:fields] = "duration,stats,created_time,pictures"
          req.headers["Accept"] = "application/vnd.vimeo.*+json;version=3.4"
          req.headers["Authorization"] = "Bearer #{access_token}"
        end

        body = JSON.parse(response.body)
        
        # Get the best quality thumbnail (largest size)
        thumbnail_sizes = body.dig("pictures", "sizes") || []
        best_thumbnail = thumbnail_sizes.max_by { |size| size["width"] || 0 }
        
        {
          duration: body.dig("duration"),
          views: body.dig("stats", "plays"),
          likes: body.dig("stats", "likes"),
          comments: body.dig("stats", "comments"),
          created_time: body.dig("created_time"),
          thumbnail_url: best_thumbnail&.dig("link"),
          thumbnail_width: best_thumbnail&.dig("width"),
          thumbnail_height: best_thumbnail&.dig("height")
        }
      end
    rescue JSON::ParserError, Faraday::Error => e
      Rails.logger.error "Failed to fetch Vimeo metadata for video #{video_id}: #{e.message}"
      {
        duration: nil,
        views: nil,
        likes: nil,
        comments: nil,
        created_time: nil,
        thumbnail_url: nil
      }
    end

    def fetch_downloads(video_id)
      response = http_client.get("/videos/#{video_id}") do |req|
        req.params[:fields] = "download"
        req.headers["Accept"] = "application/vnd.vimeo.*+json;version=3.4"
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      body = JSON.parse(response.body)
      downloads =
        case body
        when Array
          body
        when Hash
          body.fetch("download", [])
        else
          []
        end

      downloads.filter_map do |item|
        link = item.is_a?(Hash) ? item["link"] : item
        next if link.blank?

        {
          link: link,
          quality: item.is_a?(Hash) ? item["quality"] : nil,
          type: item.is_a?(Hash) ? item["type"] : nil,
          width: item.is_a?(Hash) ? item["width"] : nil,
          height: item.is_a?(Hash) ? item["height"] : nil,
          size: item.is_a?(Hash) ? item["size"] : nil,
          size_short: item.is_a?(Hash) ? item["size_short"] : nil
        }
      end
    rescue JSON::ParserError, Faraday::Error
      []
    end

    def http_client
      @http_client ||= Faraday.new(API_ROOT) do |builder|
        builder.request :url_encoded
        builder.response :raise_error
        builder.adapter Faraday.default_adapter
      end
    end

    def format_duration(seconds)
      return "0:00" if seconds.nil? || seconds <= 0

      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      secs = seconds % 60

      if hours > 0
        format("%d:%02d:%02d", hours, minutes, secs)
      else
        format("%d:%02d", minutes, secs)
      end
    end

    def format_view_count(count)
      return "0 views" if count.nil? || count <= 0

      case count
      when 0...1_000
        "#{count} views"
      when 1_000...1_000_000
        "#{(count / 1_000.0).round(1)}K views"
      else
        "#{(count / 1_000_000.0).round(1)}M views"
      end
    end

    def access_token
      ENV["VIMEO_ACCESS_TOKEN"].presence || Rails.application.credentials.dig(:vimeo, :access_token)
    end
  end
end
