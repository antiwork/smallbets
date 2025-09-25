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

    def access_token
      ENV["VIMEO_ACCESS_TOKEN"].presence || Rails.application.credentials.dig(:vimeo, :access_token)
    end
  end
end
