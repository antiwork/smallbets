module AutomatedFeed
  class Configuration
    attr_accessor :lookback_hours,
                  :max_conversations_per_scan,
                  :ai_model,
                  :enable_automated_scans,
                  :activity_message_threshold,
                  :activity_quality_message_threshold,
                  :activity_quality_participant_threshold,
                  :activity_cooldown_minutes,
                  :activity_state_ttl_minutes,
                  :room_scan_message_limit,
                  :room_scan_thread_limit,
                  :room_scan_context_backfill,
                  :room_scan_lookback_hours

    def initialize
      @lookback_hours = ENV.fetch("AUTOMATED_FEED_LOOKBACK_HOURS", "2").to_i
      @max_conversations_per_scan = ENV.fetch("AUTOMATED_FEED_MAX_CONVERSATIONS", "20").to_i
      @ai_model = ENV.fetch("AUTOMATED_FEED_AI_MODEL", "anthropic/claude-haiku-4.5")
      @enable_automated_scans = ENV.fetch("AUTOMATED_FEED_ENABLED", "true") == "true"
      @activity_message_threshold = ENV.fetch("AUTOMATED_FEED_MESSAGE_THRESHOLD", "15").to_i
      @activity_quality_message_threshold = ENV.fetch("AUTOMATED_FEED_QUALITY_MESSAGE_THRESHOLD", "8").to_i
      @activity_quality_participant_threshold = ENV.fetch("AUTOMATED_FEED_QUALITY_PARTICIPANT_THRESHOLD", "3").to_i
      @activity_cooldown_minutes = ENV.fetch("AUTOMATED_FEED_COOLDOWN_MINUTES", "30").to_i
      @activity_state_ttl_minutes = ENV.fetch("AUTOMATED_FEED_STATE_TTL_MINUTES", "240").to_i
      @room_scan_message_limit = ENV.fetch("AUTOMATED_FEED_ROOM_SCAN_MESSAGE_LIMIT", "120").to_i
      @room_scan_thread_limit = ENV.fetch("AUTOMATED_FEED_ROOM_SCAN_THREAD_LIMIT", "40").to_i
      @room_scan_context_backfill = ENV.fetch("AUTOMATED_FEED_ROOM_SCAN_CONTEXT_BACKFILL", "20").to_i
      @room_scan_lookback_hours = ENV.fetch("AUTOMATED_FEED_ROOM_SCAN_LOOKBACK_HOURS", "12").to_i
    end
  end

  class << self
    attr_accessor :config

    def configure
      self.config ||= Configuration.new
      yield(config) if block_given?
      config
    end

    def config
      @config ||= Configuration.new
    end
  end
end
