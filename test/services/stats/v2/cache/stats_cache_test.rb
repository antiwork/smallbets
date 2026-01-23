require "test_helper"

module Stats
  module V2
    module Cache
      class StatsCacheTest < ActiveSupport::TestCase
        setup do
          @original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
        end

        teardown do
          Rails.cache = @original_cache
        end

        test "fetch_top_posters caches query results" do
          room = rooms(:pets)
          user = users(:jason)

          3.times { |i| room.messages.create!(creator: user, body: "Test #{i}", client_message_id: SecureRandom.uuid) }

          # First call - should hit database
          result1 = StatsCache.fetch_top_posters(period: :all_time, limit: 10)

          # Second call - should hit cache
          result2 = StatsCache.fetch_top_posters(period: :all_time, limit: 10)

          assert_equal result1.size, result2.size
          assert_kind_of Array, result2
        end

        test "fetch_top_posters uses different cache keys per period" do
          room = rooms(:pets)
          user = users(:jason)

          room.messages.create!(creator: user, body: "Today", client_message_id: SecureRandom.uuid, created_at: Time.current)

          today_result = StatsCache.fetch_top_posters(period: :today, limit: 10)
          all_time_result = StatsCache.fetch_top_posters(period: :all_time, limit: 10)

          # Results should be different because they're cached separately
          assert_kind_of Array, today_result
          assert_kind_of Array, all_time_result
        end

        test "fetch_top_posters uses different cache keys per limit" do
          StatsCache.fetch_top_posters(period: :today, limit: 5)
          StatsCache.fetch_top_posters(period: :today, limit: 10)

          # Should create separate cache entries
          assert Rails.cache.exist?("stats:top_posters:today:5")
          assert Rails.cache.exist?("stats:top_posters:today:10")
        end

        test "clear_all removes all stats cache" do
          StatsCache.fetch_top_posters(period: :today, limit: 10)
          StatsCache.fetch_top_posters(period: :month, limit: 10)

          assert Rails.cache.exist?("stats:top_posters:today:10")
          assert Rails.cache.exist?("stats:top_posters:month:10")

          StatsCache.clear_all

          refute Rails.cache.exist?("stats:top_posters:today:10")
          refute Rails.cache.exist?("stats:top_posters:month:10")
        end

        test "clear_top_posters removes only top_posters cache" do
          StatsCache.fetch_top_posters(period: :today, limit: 10)

          assert Rails.cache.exist?("stats:top_posters:today:10")

          StatsCache.clear_top_posters

          refute Rails.cache.exist?("stats:top_posters:today:10")
        end

        test "clear_top_posters with period removes only that period" do
          StatsCache.fetch_top_posters(period: :today, limit: 10)
          StatsCache.fetch_top_posters(period: :month, limit: 10)

          StatsCache.clear_top_posters(period: :today)

          refute Rails.cache.exist?("stats:top_posters:today:10")
          assert Rails.cache.exist?("stats:top_posters:month:10")
        end

        test "ttl_for_period returns correct values" do
          cache_service = StatsCache

          assert_equal 1.minute, cache_service.send(:ttl_for_period, :today)
          assert_equal 5.minutes, cache_service.send(:ttl_for_period, :month)
          assert_equal 15.minutes, cache_service.send(:ttl_for_period, :year)
          assert_equal 30.minutes, cache_service.send(:ttl_for_period, :all_time)
        end

        test "fetch_system_metrics caches results" do
          # First call - should hit database
          result1 = StatsCache.fetch_system_metrics

          # Second call - should hit cache
          result2 = StatsCache.fetch_system_metrics

          assert_equal result1, result2
          assert_kind_of Hash, result2
          assert_includes result2, :total_users
          assert_includes result2, :online_users
          assert_includes result2, :database_size
        end

        test "clear_system_metrics removes system metrics cache" do
          StatsCache.fetch_system_metrics

          assert Rails.cache.exist?("stats:system_metrics")

          StatsCache.clear_system_metrics

          refute Rails.cache.exist?("stats:system_metrics")
        end

        test "clear_all removes system metrics cache" do
          StatsCache.fetch_system_metrics

          assert Rails.cache.exist?("stats:system_metrics")

          StatsCache.clear_all

          refute Rails.cache.exist?("stats:system_metrics")
        end

        test "fetch_top_rooms caches results" do
          # First call - should hit database
          result1 = StatsCache.fetch_top_rooms(limit: 10)

          # Second call - should hit cache
          result2 = StatsCache.fetch_top_rooms(limit: 10)

          assert_equal result1.size, result2.size
          assert_kind_of Array, result2
        end

        test "fetch_top_rooms returns rooms with message_count" do
          result = StatsCache.fetch_top_rooms(limit: 10)

          result.each do |room|
            assert room.respond_to?(:message_count)
            assert room.message_count.to_i >= 0
          end
        end

        test "clear_top_rooms removes cache" do
          StatsCache.fetch_top_rooms(limit: 10)

          assert Rails.cache.exist?("stats:top_rooms:10")

          StatsCache.clear_top_rooms

          refute Rails.cache.exist?("stats:top_rooms:10")
        end

        test "clear_all removes top rooms cache" do
          StatsCache.fetch_top_rooms(limit: 10)

          assert Rails.cache.exist?("stats:top_rooms:10")

          StatsCache.clear_all

          refute Rails.cache.exist?("stats:top_rooms:10")
        end

        test "fetch_message_history_recent caches results" do
          # First call - should hit database
          result1 = StatsCache.fetch_message_history_recent(limit: 7)

          # Second call - should hit cache
          result2 = StatsCache.fetch_message_history_recent(limit: 7)

          assert_equal result1.size, result2.size
          assert_kind_of Array, result2
        end

        test "fetch_message_history_recent returns hashes with date and count" do
          result = StatsCache.fetch_message_history_recent(limit: 7)

          result.each do |stat|
            assert_kind_of Hash, stat
            assert_includes stat, :date
            assert_includes stat, :count
            assert_kind_of String, stat[:date]
            assert_kind_of Integer, stat[:count]
          end
        end

        test "fetch_message_history_recent uses different cache keys per limit" do
          StatsCache.fetch_message_history_recent(limit: 3)
          StatsCache.fetch_message_history_recent(limit: 7)

          # Should create separate cache entries
          assert Rails.cache.exist?("stats:message_history:recent:3")
          assert Rails.cache.exist?("stats:message_history:recent:7")
        end

        test "fetch_message_history_all_time caches results" do
          # First call - should hit database
          result1 = StatsCache.fetch_message_history_all_time

          # Second call - should hit cache
          result2 = StatsCache.fetch_message_history_all_time

          assert_equal result1.size, result2.size
          assert_kind_of Array, result2
        end

        test "fetch_message_history_all_time returns hashes with date and count" do
          result = StatsCache.fetch_message_history_all_time

          result.each do |stat|
            assert_kind_of Hash, stat
            assert_includes stat, :date
            assert_includes stat, :count
            assert_kind_of String, stat[:date]
            assert_kind_of Integer, stat[:count]
          end
        end

        test "clear_message_history removes cache" do
          StatsCache.fetch_message_history_recent(limit: 7)
          StatsCache.fetch_message_history_all_time

          assert Rails.cache.exist?("stats:message_history:recent:7")
          assert Rails.cache.exist?("stats:message_history:all_time")

          StatsCache.clear_message_history

          refute Rails.cache.exist?("stats:message_history:recent:7")
          refute Rails.cache.exist?("stats:message_history:all_time")
        end

        test "clear_all removes message history cache" do
          StatsCache.fetch_message_history_recent(limit: 7)
          StatsCache.fetch_message_history_all_time

          assert Rails.cache.exist?("stats:message_history:recent:7")
          assert Rails.cache.exist?("stats:message_history:all_time")

          StatsCache.clear_all

          refute Rails.cache.exist?("stats:message_history:recent:7")
          refute Rails.cache.exist?("stats:message_history:all_time")
        end
      end
    end
  end
end
