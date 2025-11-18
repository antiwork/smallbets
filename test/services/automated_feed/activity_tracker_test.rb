require "test_helper"
require "set"

module AutomatedFeed
  class ActivityTrackerTest < ActiveSupport::TestCase
    class FakeRedis
      def initialize
        @data = {}
        @sets = Hash.new { |hash, key| hash[key] = Set.new }
        @in_pipeline = false
        @pipeline_results = []
      end

      def pipelined
        previous_state = @in_pipeline
        @in_pipeline = true
        @pipeline_results = []
        yield self
        results = @pipeline_results.dup
        @in_pipeline = previous_state
        @pipeline_results = []
        results
      end

      def incr(key)
        @data[key] = @data.fetch(key, 0).to_i + 1
        record_pipeline_result(@data[key])
      end

      def expire(_key, _seconds)
        # TTL not needed for tests
      end

      def sadd(key, value)
        @sets[key] << value
        record_pipeline_result(1)
      end

      def set(key, value, nx: false, ex: nil)
        if nx && exists(key).positive?
          record_pipeline_result(nil)
          return nil
        end

        @data[key] = value.to_i
        record_pipeline_result("OK")
        "OK"
      end

      def get(key)
        value = @data[key]
        string_value = value.nil? ? nil : value.to_s
        record_pipeline_result(string_value)
        string_value
      end

      def scard(key)
        count = @sets[key].size
        record_pipeline_result(count)
        count
      end

      def exists(key)
        exists = (@data.key?(key) || @sets.key?(key)) ? 1 : 0
        record_pipeline_result(exists)
        exists
      end

      def del(*keys)
        keys.each do |key|
          @data.delete(key)
          @sets.delete(key)
        end
        true
      end

      def scan(_cursor, match:, count: nil)
        keys = (@data.keys + @sets.keys).uniq
        matching = keys.select { |key| File.fnmatch?(match, key) }
        # emulate redis returning limited batch
        batch = count ? matching.first(count) : matching
        ["0", batch]
      end

      private

      def record_pipeline_result(value)
        @pipeline_results << value if @in_pipeline
        value
      end
    end

    setup do
      configure_thresholds(messages: 2, quality_messages: 2, quality_participants: 2)
    end

    teardown do
      configure_thresholds(messages: 15, quality_messages: 8, quality_participants: 3)
    end

    test "record triggers when message threshold reached and acquires lock" do
      fake = FakeRedis.new
      AutomatedFeed::ActivityTracker.stubs(:redis).returns(fake)

      message = messages(:first)

      first = AutomatedFeed::ActivityTracker.record(message)
      refute first[:trigger?]
      assert_equal :monitoring, first[:status]

      second = AutomatedFeed::ActivityTracker.record(message)
      assert second[:trigger?]
      assert_equal :message_threshold, second[:status]
      assert_equal message.room_id, second[:room_id]

      third = AutomatedFeed::ActivityTracker.record(message)
      refute third[:trigger?]
      assert_equal :locked, third[:status]

      assert_equal [message.room_id.to_s], AutomatedFeed::ActivityTracker.active_room_ids
    end

    test "mark_scanned clears counters and enforces cooldown" do
      fake = FakeRedis.new
      AutomatedFeed::ActivityTracker.stubs(:redis).returns(fake)

      message = messages(:first)
      result = AutomatedFeed::ActivityTracker.record(message)
      refute result[:trigger?]

      trigger = AutomatedFeed::ActivityTracker.record(message)
      assert trigger[:trigger?]

      AutomatedFeed::ActivityTracker.mark_scanned(trigger[:room_id])

      cooldown = AutomatedFeed::ActivityTracker.should_scan?(trigger[:room_id])
      refute cooldown[:trigger?]
      assert_equal :cooldown, cooldown[:status]

      stats_after_reset = AutomatedFeed::ActivityTracker.record(message)
      refute stats_after_reset[:trigger?]
    end

    test "record ignores conversation rooms" do
      fake = FakeRedis.new
      AutomatedFeed::ActivityTracker.stubs(:redis).returns(fake)

      message = messages(:first)
      room = message.room
      room.stubs(:conversation_room?).returns(true)

      ignored = AutomatedFeed::ActivityTracker.record(message)
      refute ignored[:trigger?]
      assert_equal :ignored, ignored[:status]
      assert_nil ignored[:room_id]
    ensure
      room.unstub(:conversation_room?)
    end

    private

    def configure_thresholds(messages:, quality_messages:, quality_participants:)
      AutomatedFeed.config.activity_message_threshold = messages
      AutomatedFeed.config.activity_quality_message_threshold = quality_messages
      AutomatedFeed.config.activity_quality_participant_threshold = quality_participants
    end
  end
end
