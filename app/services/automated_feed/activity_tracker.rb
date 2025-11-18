module AutomatedFeed
  class ActivityTracker
    TRACKER_NAMESPACE = "automated_feed:activity".freeze

    class << self
      def record(message)
        config = AutomatedFeed.config
        return ignored_result unless config.enable_automated_scans

        room = canonical_room(message.room)
        return ignored_result unless eligible_room?(room, message)

        room_id = room.id
        creator_id = message.creator_id
        return ignored_result unless room_id && creator_id

        increment_activity(room_id, creator_id)

        stats = current_stats(room_id)
        decision = evaluate_trigger(room_id, stats)
        decision = ensure_lock(room_id, decision) if decision[:trigger?]

        decision.merge(room_id: room_id, message_count: stats[:message_count], participant_count: stats[:participant_count])
      rescue StandardError => error
        Rails.logger.error("[AutomatedFeed::ActivityTracker] Failed to record message #{message.id}: #{error.class} - #{error.message}")
        Sentry.capture_exception(error, extra: { message_id: message.id }) if defined?(Sentry)
        ignored_result
      end

      def reset(room_id)
        keys = activity_keys(room_id)
        redis.del(*keys.values)
      rescue Redis::BaseError => error
        Rails.logger.error("[AutomatedFeed::ActivityTracker] Redis error while resetting room #{room_id}: #{error.class} - #{error.message}")
        Sentry.capture_exception(error, extra: { room_id: room_id }) if defined?(Sentry)
      end

      def mark_scanned(room_id)
        reset(room_id)
        set_last_scan(room_id, Time.current)
      end

      def should_scan?(room_id)
        stats = current_stats(room_id)
        evaluate_trigger(room_id, stats)
          .merge(room_id: room_id, message_count: stats[:message_count], participant_count: stats[:participant_count])
      end

      def cooldown_remaining_seconds(room_id)
        last_scan_ts = redis.get(activity_keys(room_id)[:last_scan])
        return 0 unless last_scan_ts

        elapsed = Time.current.to_i - last_scan_ts.to_i
        remaining = cooldown_seconds - elapsed
        remaining.positive? ? remaining : 0
      rescue Redis::BaseError => error
        Rails.logger.error("[AutomatedFeed::ActivityTracker] Redis error while reading cooldown for room #{room_id}: #{error.class} - #{error.message}")
        0
      end

      def active_room_ids
        ids = []
        cursor = "0"

        loop do
          cursor, keys = redis.scan(cursor, match: activity_pattern("messages"), count: 100)
          ids.concat(keys.filter_map { |key| key.split(":")[-2] })
          break if cursor == "0"
        end

        ids.uniq
      rescue Redis::BaseError => error
        Rails.logger.error("[AutomatedFeed::ActivityTracker] Redis error while scanning keys: #{error.class} - #{error.message}")
        []
      end

      private

      def increment_activity(room_id, creator_id)
        keys = activity_keys(room_id)

        redis.pipelined do |pipeline|
          pipeline.incr(keys[:messages])
          pipeline.expire(keys[:messages], state_ttl_seconds)
          pipeline.sadd(keys[:participants], creator_id)
          pipeline.expire(keys[:participants], state_ttl_seconds)
          pipeline.set(keys[:last_message], Time.current.to_i, ex: state_ttl_seconds)
        end
      end

      def current_stats(room_id)
        keys = activity_keys(room_id)

        values = redis.pipelined do |pipeline|
          pipeline.get(keys[:messages])
          pipeline.scard(keys[:participants])
          pipeline.get(keys[:last_scan])
          pipeline.exists(keys[:scan_lock])
        end

        {
          message_count: values[0].to_i,
          participant_count: values[1].to_i,
          last_scan_at: values[2]&.to_i,
          scan_locked: values[3].to_i.positive?
        }
      rescue Redis::BaseError => error
        Rails.logger.error("[AutomatedFeed::ActivityTracker] Redis error while fetching stats for room #{room_id}: #{error.class} - #{error.message}")
        { message_count: 0, participant_count: 0, last_scan_at: nil, scan_locked: false }
      end

      def evaluate_trigger(room_id, stats)
        return { trigger?: false, status: :cooldown } if in_cooldown?(stats[:last_scan_at])
        return { trigger?: false, status: :locked } if stats[:scan_locked]

        if stats[:message_count] >= AutomatedFeed.config.activity_message_threshold
          { trigger?: true, status: :message_threshold }
        elsif stats[:message_count] >= AutomatedFeed.config.activity_quality_message_threshold &&
              stats[:participant_count] >= AutomatedFeed.config.activity_quality_participant_threshold
          { trigger?: true, status: :quality_threshold }
        else
          { trigger?: false, status: :monitoring }
        end
      end

      def ensure_lock(room_id, decision)
        acquire_scan_lock(room_id) ? decision : { trigger?: false, status: :locked }
      end

      def in_cooldown?(last_scan_timestamp)
        return false unless last_scan_timestamp

        last_scan_time = Time.at(last_scan_timestamp)
        last_scan_time >= cooldown_seconds.seconds.ago
      end

      def set_last_scan(room_id, time)
        redis.set(activity_keys(room_id)[:last_scan], time.to_i, ex: state_ttl_seconds)
      rescue Redis::BaseError => error
        Rails.logger.error("[AutomatedFeed::ActivityTracker] Redis error while setting last scan for room #{room_id}: #{error.class} - #{error.message}")
      end

      def acquire_scan_lock(room_id)
        redis.set(activity_keys(room_id)[:scan_lock], Time.current.to_i, nx: true, ex: state_ttl_seconds)
      rescue Redis::BaseError => error
        Rails.logger.error("[AutomatedFeed::ActivityTracker] Redis error while acquiring scan lock for room #{room_id}: #{error.class} - #{error.message}")
        false
      end

      def canonical_room(room)
        return unless room

        if room.thread?
          parent_room = room.parent_message&.room
          parent_room || room
        else
          room
        end
      end

      def eligible_room?(room, message)
        return false unless room&.active?
        return false if room.direct?
        return false if room.conversation_room?
        return false if message.original_message_id.present?

        true
      end

      def ignored_result
        { trigger?: false, status: :ignored, room_id: nil, message_count: 0, participant_count: 0 }
      end

      def activity_keys(room_id)
        base = "#{TRACKER_NAMESPACE}:#{room_id}"
        {
          messages: activity_key(base, "messages"),
          participants: activity_key(base, "participants"),
          last_message: activity_key(base, "last_message"),
          last_scan: activity_key(base, "last_scan"),
          scan_lock: activity_key(base, "scan_lock")
        }
      end

      def activity_key(base, suffix)
        "#{base}:#{suffix}"
      end

      def activity_pattern(suffix)
        "#{TRACKER_NAMESPACE}:*:#{suffix}"
      end

      def state_ttl_seconds
        (AutomatedFeed.config.activity_state_ttl_minutes * 60).clamp(300, 86_400)
      end

      def cooldown_seconds
        AutomatedFeed.config.activity_cooldown_minutes * 60
      end

      def redis
        Kredis.redis
      end
    end
  end
end
