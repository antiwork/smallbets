module Vimeo
  module ThumbnailFetcher
    API_ROOT = "https://api.vimeo.com".freeze
    CACHE_VERSION = "v2".freeze
    # Hard/Redis TTL: keep entries for a long time to maximize cache hits
    LONG_TTL = 30.days
    # Soft TTL window: after this, entries are considered stale and should be refreshed
    SOFT_TTL = 7.days
    CACHE_TTL = LONG_TTL
    NEGATIVE_TTL = 5.minutes

    module_function

    # Non-blocking read of cached thumbnails. Does not trigger network.
    def read_cached(video_id)
      key = cache_key(video_id)
      return nil unless Rails.cache.exist?(key)
      value = Rails.cache.read(key)

      # If the cached value is present but stale, enqueue a background refresh
      if value.present? && stale?(value)
        enqueue(video_id)
        Rails.logger.info(
          "vimeo.thumbnail_fetcher.stale_enqueued" => {
            video_id: video_id.to_s,
            fetched_at: value["fetchedAt"]
          }
        )
      end

      value
    end

    def read_cached_many(video_ids)
      Array(video_ids).compact_blank.each_with_object({}) do |video_id, acc|
        value = read_cached(video_id)
        acc[video_id.to_s] = value if value.present?
      end
    end

    def enqueue(video_id)
      Vimeo::FetchThumbnailJob.perform_later(video_id.to_s)
    end

    def enqueue_many(video_ids)
      Array(video_ids).compact_blank.each { |id| enqueue(id) }
    end

    def fetch(video_id)
      normalized_id = video_id.to_s.strip
      raise ArgumentError, "video_id is blank" if normalized_id.blank?

      Rails.cache.fetch(cache_key(normalized_id), expires_in: CACHE_TTL) do
        # If we don't have a token configured, avoid network and cache negative briefly
        if access_token.blank?
          Rails.logger.warn("vimeo.thumbnail_fetcher.no_token" => { video_id: normalized_id })
          cache_negative(normalized_id)
        else
          fetch_from_vimeo(normalized_id)
        end
      end
    rescue Faraday::Error => error
      Rails.logger.warn("vimeo.thumbnail_fetcher.http_error" => { video_id: normalized_id, error: error.class.name, message: error.message })
      cache_negative(normalized_id)
    rescue JSON::ParserError => error
      Rails.logger.warn("vimeo.thumbnail_fetcher.parse_error" => { video_id: normalized_id, error: error.message })
      cache_negative(normalized_id)
    rescue KeyError => error
      # Handles cases like missing sizes array
      Rails.logger.warn("vimeo.thumbnail_fetcher.missing_data" => { video_id: normalized_id, error: error.message })
      cache_negative(normalized_id)
    end

    def fetch_many(video_ids)
      Array(video_ids).compact_blank.each_with_object({}) do |video_id, acc|
        begin
          thumbnail = fetch(video_id)
          acc[video_id.to_s] = thumbnail if thumbnail.present?
        rescue ArgumentError
          next
        end
      end
    end

    def cache_key(video_id)
      "vimeo:thumbs:#{CACHE_VERSION}:#{video_id}"
    end

    def http_client
      @http_client ||= Faraday.new(API_ROOT) do |builder|
        builder.request :url_encoded
        builder.response :raise_error
        builder.adapter Faraday.default_adapter
      end
    end

    def access_token
      ENV["VIMEO_ACCESS_TOKEN"].presence || Rails.application.credentials.dig(:vimeo, :access_token)
    end

    def fetch_from_vimeo(video_id)
      response = http_client.get("/videos/#{video_id}") do |request|
        request.params[:fields] = "pictures.base_link,pictures.sizes.link,pictures.sizes.width,pictures.sizes.height,duration"
        request.headers["Accept"] = "application/vnd.vimeo.*+json;version=3.4"
        request.headers["Authorization"] = "Bearer #{access_token}"
      end

      payload = JSON.parse(response.body)
      pictures = payload.fetch("pictures") { {} }
      duration_seconds = payload["duration"].to_i if payload.key?("duration")
      sizes = Array(pictures["sizes"]).filter_map do |entry|
        next unless entry.is_a?(Hash)

        link = entry["link"].presence
        width = entry["width"]
        height = entry["height"]
        next unless link && width && height

        {
          link: link,
          width: width,
          height: height
        }
      end

      raise KeyError, "no vimeo picture sizes" if sizes.empty?

      best = sizes.max_by { |entry| entry[:width] }
      srcset = sizes.sort_by { |entry| entry[:width] }.map { |entry| "#{entry[:link]} #{entry[:width]}w" }.join(", ")

      {
        "id" => video_id.to_s,
        "baseLink" => pictures["base_link"],
        "src" => best[:link],
        "srcset" => srcset,
        "width" => best[:width],
        "height" => best[:height],
        "durationSeconds" => duration_seconds,
        "sizes" => sizes,
        "fetchedAt" => Time.current.iso8601
      }
    end

    def cache_negative(video_id)
      Rails.cache.write(cache_key(video_id), nil, expires_in: NEGATIVE_TTL)
      nil
    end

    # Returns true when a cached thumbnail payload is older than the soft TTL window.
    def stale?(entry)
      return false if entry.blank?
      fetched_at = entry.is_a?(Hash) ? entry["fetchedAt"] : nil
      return false if fetched_at.blank?

      begin
        fetched_time = Time.zone.parse(fetched_at)
      rescue ArgumentError, TypeError
        return true
      end

      return true if fetched_time.blank?
      fetched_time < SOFT_TTL.ago
    end
  end
end
