require_relative "../conversation_rooms/validator"

module AutomatedFeed
  class ScanRunner
    def initialize(conversations:, source:, room: nil)
      @conversations = Array(conversations)
      @source = source
      @room = room
    end

    def run
      return if @conversations.empty?

      Rails.logger.info("[AutomatedFeed::ScanRunner] Processing #{@conversations.count} conversations (source: #{@source})")

      @conversations.each do |conversation|
        process_conversation(conversation)
      rescue StandardError => error
        Rails.logger.error("[AutomatedFeed::ScanRunner] Error processing conversation: #{error.class} - #{error.message}")
        Rails.logger.error(error.backtrace.join("\n"))
        Sentry.capture_exception(error, extra: { conversation:, source: @source, room_id: @room&.id }) if defined?(Sentry)
      end
    end

    private

    def process_conversation(conversation)
      source_room_id = determine_source_room_id(conversation[:message_ids])
      Rails.logger.info("[AutomatedFeed::ScanRunner] Determined source_room_id: #{source_room_id} for conversation with messages: #{conversation[:message_ids]}")
      
      # If scanning a specific room, ensure the source room matches
      if @room.present? && source_room_id.present? && source_room_id != @room.id
        Rails.logger.info("[AutomatedFeed::ScanRunner] Skipping conversation: source_room_id #{source_room_id} doesn't match scanned room #{@room.id}")
        return
      end
      
      if conversation[:message_ids].length == 1
        Rails.logger.info("[AutomatedFeed::ScanRunner] Single message detected - checking for continuation only")
        dedup_result = AutomatedFeed::Deduplicator.check(conversation: conversation, source_room_id: source_room_id)
        
        if dedup_result[:action] == :continuation
          update_existing_feed_card(conversation, dedup_result[:card])
        else
          Rails.logger.info("[AutomatedFeed::ScanRunner] Single message not a continuation - skipping (#{dedup_result[:action]})")
        end
        return
      end
      
      dedup_result = AutomatedFeed::Deduplicator.check(conversation: conversation, source_room_id: source_room_id)

      case dedup_result[:action]
      when :skip
        Rails.logger.info("[AutomatedFeed::ScanRunner] Skipping conversation: #{dedup_result[:reason]}")
      when :new_topic
        create_new_feed_card(conversation)
      when :continuation
        update_existing_feed_card(conversation, dedup_result[:card])
      else
        Rails.logger.warn("[AutomatedFeed::ScanRunner] Unknown dedup action: #{dedup_result[:action]}")
      end
    end

    def create_new_feed_card(conversation)
      # Filter out already-in-feed messages - they're only for AI context, not for new conversations
      non_feed_ids = filter_non_feed_messages(conversation[:message_ids])
      
      if non_feed_ids.empty?
        Rails.logger.info("[AutomatedFeed::ScanRunner] Skipping conversation - all messages already in feed")
        return
      end

      if non_feed_ids.length < conversation[:message_ids].length
        Rails.logger.info("[AutomatedFeed::ScanRunner] Filtered out #{conversation[:message_ids].length - non_feed_ids.length} already-in-feed messages")
      end

      fingerprint_result = check_fingerprint_before_create(non_feed_ids)
      return if fingerprint_result[:action] == :skip

      Rails.logger.info("[AutomatedFeed::ScanRunner] Creating card with preview_message_id: #{conversation[:preview_message_id].inspect}")

      result = RoomCreator.create_conversation_room(
        message_ids: non_feed_ids,
        title: conversation[:title],
        summary: conversation[:summary],
        key_insight: conversation[:key_insight],
        preview_message_id: conversation[:preview_message_id],
        type: "automated",
        promoted_by: nil
      )

      Rails.logger.info("[AutomatedFeed::ScanRunner] Created new feed card: #{conversation[:title]} (preview: #{result[:feed_card].preview_message_id})")
    rescue RoomCreator::Error => error
      Rails.logger.error("[AutomatedFeed::ScanRunner] Failed to create room: #{error.message}")
      raise
    end

    def update_existing_feed_card(conversation, card)
      # For continuations, pass ALL message IDs (including in-feed ones) for better context
      # RoomUpdater will filter out messages that are already in the feed card's room
      AutomatedFeed::RoomUpdater.update_continuation(
        feed_card: card,
        new_message_ids: conversation[:message_ids],
        updated_summary: nil
      )

      Rails.logger.info("[AutomatedFeed::ScanRunner] Updated existing feed card #{card.id} with continuation")
    rescue RoomUpdater::Error => error
      Rails.logger.error("[AutomatedFeed::ScanRunner] Failed to update room: #{error.message}")
      raise
    end

    def check_fingerprint_before_create(message_ids)
      sorted_ids = message_ids.sort
      fingerprint = Digest::SHA256.hexdigest(sorted_ids.join(","))

      existing_card = AutomatedFeedCard.find_by(message_fingerprint: fingerprint)
      if existing_card
        Rails.logger.info("[AutomatedFeed::ScanRunner] Fingerprint match found, skipping creation")
        return { action: :skip, reason: "fingerprint_match" }
      end

      { action: :continue }
    end

    def filter_non_feed_messages(message_ids)
      non_feed_ids = Message.where(id: message_ids).where(in_feed: false).pluck(:id)
      message_ids & non_feed_ids
    end

    def determine_source_room_id(message_ids)
      messages = Message.where(id: message_ids).includes(:room, room: :parent_message)
      return nil if messages.empty?

      analysis = ConversationRooms::Validator.analyze(messages: messages)

      unless analysis.valid?
        Rails.logger.warn("[AutomatedFeed::ScanRunner] Cannot determine source_room_id: #{analysis.reason}")
        return nil
      end

      analysis.source_room&.id
    end
  end
end
