require "test_helper"

module Api
  module Videos
    class ThumbnailsControllerTest < ActionDispatch::IntegrationTest
      setup do
        sign_in :david
        @cache = ActiveSupport::Cache::MemoryStore.new
        @previous_cache = Rails.cache
        Rails.cache = @cache
        @previous_token = ENV["VIMEO_ACCESS_TOKEN"]
        ENV["VIMEO_ACCESS_TOKEN"] = "test-token"
      end

      teardown do
        Rails.cache = @previous_cache
        ENV["VIMEO_ACCESS_TOKEN"] = @previous_token
        WebMock.reset!
      end

      test "returns cached thumbnails" do
        Rails.cache.write(Vimeo::ThumbnailFetcher.cache_key("123"), thumb_payload_for("123", 640))

        get api_videos_thumbnails_url(ids: "123"), headers: { "Accept" => "application/json" }

        assert_response :success
        body = response.parsed_body
        assert_equal "https://example.com/640.jpg", body.dig("123", "src")

        WebMock.reset!

        get api_videos_thumbnails_url(ids: "123"), headers: { "Accept" => "application/json" }
        assert_response :success
        assert WebMock::RequestRegistry.instance.requested_signatures.hash.empty?
      end

      test "returns empty json on cache miss and enqueues fetch" do
        previous_adapter = ActiveJob::Base.queue_adapter
        ActiveJob::Base.queue_adapter = :test
        begin
          assert_enqueued_with(job: Vimeo::FetchThumbnailJob, args: ["999"]) do
            get api_videos_thumbnails_url(ids: "999"), headers: { "Accept" => "application/json" }
            assert_response :success
            body = response.parsed_body
            assert_equal({}, body)
          end
        ensure
          ActiveJob::Base.queue_adapter = previous_adapter
        end
      end

      private

      def stub_vimeo(id, payload)
        stub_request(:get, "https://api.vimeo.com/videos/#{id}")
          .with(query: { "fields" => fields }, headers: auth_headers)
          .to_return(status: 200, body: payload.to_json, headers: { "Content-Type" => "application/json" })
      end

      def thumb_payload_for(id, width)
        {
          "id" => id.to_s,
          "baseLink" => "https://example.com/base-#{id}.jpg",
          "src" => "https://example.com/#{width}.jpg",
          "srcset" => "https://example.com/#{width}.jpg #{width}w",
          "width" => width,
          "height" => (width / 16.0 * 9).round,
          "sizes" => [
            { "link" => "https://example.com/#{width}.jpg", "width" => width, "height" => (width / 16.0 * 9).round }
          ],
          "fetchedAt" => Time.current.iso8601
        }
      end

      def fields
        "pictures.base_link,pictures.sizes.link,pictures.sizes.width,pictures.sizes.height"
      end

      def auth_headers
        {
          "Authorization" => "Bearer test-token",
          "Accept" => "application/vnd.vimeo.*+json;version=3.4"
        }
      end
    end
  end
end

