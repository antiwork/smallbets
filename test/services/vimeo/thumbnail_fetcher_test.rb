require "test_helper"

module Vimeo
  class ThumbnailFetcherTest < ActiveSupport::TestCase
    setup do
      @cache = ActiveSupport::Cache::MemoryStore.new
      @previous_cache = Rails.cache
      Rails.cache = @cache
      @previous_token = ENV["VIMEO_ACCESS_TOKEN"]
      ENV["VIMEO_ACCESS_TOKEN"] = "test-token"
    end

    teardown do
      Rails.cache = @previous_cache
      WebMock.reset!
      ENV["VIMEO_ACCESS_TOKEN"] = @previous_token
    end

    test "fetch caches thumbnail response" do
      stub_vimeo_video("123", build_payload([size(320), size(1280)]))

      payload = ThumbnailFetcher.fetch("123")

      assert_equal "123", payload["id"]
      assert_equal "https://example.com/1280.jpg", payload["src"]
      assert_equal "https://example.com/320.jpg 320w, https://example.com/1280.jpg 1280w", payload["srcset"]

      # second call should hit cache and not re-request
      WebMock.reset!
      cached = ThumbnailFetcher.fetch("123")

      assert_equal payload, cached
    end

    test "fetch_many hydrates multiple ids" do
      stub_vimeo_video("1", build_payload([size(640)]))
      stub_vimeo_video("2", build_payload([size(800)]))

      result = ThumbnailFetcher.fetch_many(%w[1 2])

      assert_equal %w[1 2], result.keys
      assert_equal "https://example.com/800.jpg", result["2"]["src"]
    end

    test "fetch caches nil on error" do
      stub_request(:get, "https://api.vimeo.com/videos/404")
        .with(query: query_params, headers: auth_headers)
        .to_return(status: 404)

      assert_nil ThumbnailFetcher.fetch("404")

      assert Rails.cache.exist?(ThumbnailFetcher.cache_key("404"))
    end

    test "read_cached enqueues refresh when stale" do
      previous_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      begin
        stale = {
          "id" => "123",
          "src" => "https://example.com/640.jpg",
          "srcset" => "https://example.com/640.jpg 640w",
          "width" => 640,
          "height" => 360,
          "sizes" => [],
          "fetchedAt" => 8.days.ago.iso8601
        }
        Rails.cache.write(ThumbnailFetcher.cache_key("123"), stale)

        assert_enqueued_with(job: Vimeo::FetchThumbnailJob, args: ["123"]) do
          value = ThumbnailFetcher.read_cached("123")
          assert_equal "https://example.com/640.jpg", value["src"]
        end
      ensure
        ActiveJob::Base.queue_adapter = previous_adapter
      end
    end

    private

    def stub_vimeo_video(id, body)
      stub_request(:get, "https://api.vimeo.com/videos/#{id}")
        .with(query: query_params, headers: auth_headers)
        .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
    end

    def build_payload(sizes)
      {
        "pictures" => {
          "base_link" => "https://example.com/base.jpg",
          "sizes" => sizes
        }
      }
    end

    def size(width)
      {
        "link" => "https://example.com/#{width}.jpg",
        "width" => width,
        "height" => (width / 16.0 * 9).round
      }
    end

    def query_params
      {
        "fields" => "pictures.base_link,pictures.sizes.link,pictures.sizes.width,pictures.sizes.height"
      }
    end

    def auth_headers
      {
        "Authorization" => "Bearer test-token",
        "Accept" => "application/vnd.vimeo.*+json;version=3.4"
      }
    end
  end
end

