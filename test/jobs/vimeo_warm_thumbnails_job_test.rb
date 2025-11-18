require "test_helper"

module Vimeo
  class WarmThumbnailsJobTest < ActiveSupport::TestCase
    setup do
      @previous_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      @cache = ActiveSupport::Cache::MemoryStore.new
      @previous_cache = Rails.cache
      Rails.cache = @cache
    end

    teardown do
      Rails.cache = @previous_cache
      ActiveJob::Base.queue_adapter = @previous_adapter
    end

    test "discovers ids from LibrarySession and enqueues missing" do
      ids = LibrarySession.order(:position).pluck(:vimeo_id).map(&:to_s)
      assert ids.any?, "expected fixtures to provide library sessions"

      # Seed cache for half the ids to simulate warm entries
      half = ids.each_slice(2).map(&:first).compact
      half.each do |id|
        Rails.cache.write(ThumbnailFetcher.cache_key(id), {
          "id" => id,
          "src" => "https://example.com/640.jpg",
          "srcset" => "https://example.com/640.jpg 640w",
          "width" => 640,
          "height" => 360,
          "sizes" => [],
          "fetchedAt" => Time.current.iso8601
        })
      end

      assert_enqueued_jobs 0
      WarmThumbnailsJob.perform_now

      # Expect enqueues for the other half
      enqueued = enqueued_jobs.select { |j| j[:job] == Vimeo::FetchThumbnailJob }
      enqueued_ids = enqueued.flat_map { |j| j[:args] }.map(&:to_s)
      expected = ids - half
      assert_equal expected.sort, enqueued_ids.sort
    end

    test "limits how many are enqueued when limit provided" do
      WarmThumbnailsJob.perform_now(limit: 1)
      enqueued = enqueued_jobs.select { |j| j[:job] == Vimeo::FetchThumbnailJob }
      assert_equal 1, enqueued.size
    end
  end
end
