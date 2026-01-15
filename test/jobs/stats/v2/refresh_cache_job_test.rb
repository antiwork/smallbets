require "test_helper"

module Stats
  module V2
    class RefreshCacheJobTest < ActiveJob::TestCase
      setup do
        @original_cache = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
      end

      teardown do
        Rails.cache = @original_cache
      end

      test "perform refreshes cache for all periods" do
        room = rooms(:pets)
        user = users(:jason)

        3.times { |i| room.messages.create!(creator: user, body: "Test #{i}", client_message_id: SecureRandom.uuid) }

        RefreshCacheJob.new.perform

        # Check that cache entries exist for all periods
        assert Rails.cache.exist?("stats:top_posters:today:10")
        assert Rails.cache.exist?("stats:top_posters:month:10")
        assert Rails.cache.exist?("stats:top_posters:year:10")
        assert Rails.cache.exist?("stats:top_posters:all_time:10")
      end

      test "perform can be enqueued" do
        assert_enqueued_with(job: RefreshCacheJob) do
          RefreshCacheJob.perform_later
        end
      end

      test "job uses stats queue" do
        assert_equal "stats", RefreshCacheJob.new.queue_name
      end
    end
  end
end
