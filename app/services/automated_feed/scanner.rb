require_relative "../../services/ai_gateway"
require_relative "../../services/feed_prompts"
require_relative "../conversation_rooms/validator"

module AutomatedFeed
  class Scanner
    class Error < StandardError; end

    def self.scan(room: nil)
      new(room: room).scan
    end

    def initialize(room: nil)
      @config = AutomatedFeed.config
      @room = room
    end

    def scan
      return [] unless @config.enable_automated_scans

      messages = fetch_recent_messages.to_a
      return [] if messages.empty?

      log_scan(messages)

      conversations = detect_conversations(messages)
      apply_conversation_cap(conversations)
    end

    private

    attr_reader :config, :room

    def fetch_recent_messages
      if room.present?
        return Message.none unless eligible_room_for_scan?(room)

        ids = room_ids_for_scan(room)
        return [] if ids.empty?

        base_scope = Message.active
                             .where(room_id: ids)
                             .where.not(room_id: excluded_room_ids)
                             .includes(:creator, :room, :boosts, :rich_text_body)

        recent_scope = base_scope.where("messages.created_at >= ?", room_scan_lookback_start)

        recent_messages = recent_scope
                           .order(created_at: :desc)
                           .limit(room_scan_message_limit)
                           .to_a

        messages = recent_messages

        remaining = room_scan_message_limit - recent_messages.size
        if remaining.positive?
          backlog_scope = base_scope
                            .where("messages.created_at < ?", room_scan_lookback_start)
                            .where("messages.created_at >= ?", 7.days.ago)
                            .where(in_feed: false)

          backlog_messages = backlog_scope
                              .order(created_at: :desc)
                              .limit(remaining + room_scan_context_backfill)
                              .to_a

          messages = (recent_messages + backlog_messages).uniq { |msg| msg.id }
        end

        messages.sort_by!(&:created_at)

        backfill = room_scan_context_backfill
        if backfill.positive? && messages.any?
          earliest_timestamp = messages.first.created_at

          # Limit context backfill to last 7 days to avoid pulling very old messages
          context_messages = base_scope
                               .where("messages.created_at < ?", earliest_timestamp)
                               .where("messages.created_at >= ?", 7.days.ago)
                               .order(created_at: :desc)
                               .limit(backfill)
                               .to_a

          messages = (context_messages + messages).uniq { |msg| msg.id }
          messages.sort_by!(&:created_at)
        end

        messages
      else
        lookback_start = config.lookback_hours.hours.ago

        Message.active
               .not_in_feed
               .where.not(room_id: excluded_room_ids)
               .includes(:creator, :room, :boosts, :rich_text_body)
               .between(lookback_start, Time.current)
               .order(:created_at)
               .limit(500)
      end
    end

    def eligible_room_for_scan?(room)
      room.active? && !room.direct? && !room.conversation_room?
    end

    def room_ids_for_scan(room)
      base_ids = [room.id]

      thread_room_ids = Rooms::Thread.active
                                     .where(parent_message_id: room.messages.select(:id))
                                     .joins(:messages)
                                     .merge(Message.active)
                                     .where("messages.created_at >= ?", room_scan_lookback_start)
                                     .group("rooms.id")
                                     .order(Arel.sql("MAX(messages.created_at) DESC"))
                                     .limit(room_scan_thread_limit)
                                     .pluck("rooms.id")

      (base_ids + thread_room_ids).uniq
    end

    def excluded_room_ids
      Room.where.not(source_room_id: nil)
          .or(Room.where(type: "Rooms::Direct"))
          .select(:id)
    end

    def log_scan(messages)
      if room.present?
        in_feed_count = messages.count(&:in_feed?)
        recent_count = messages.count { |m| m.created_at >= room_scan_lookback_start }
        old_count = messages.size - recent_count
        
        oldest_msg = messages.min_by(&:created_at)
        newest_msg = messages.max_by(&:created_at)
        
        Rails.logger.info "[AutomatedFeed::Scanner] Scanning #{messages.size} messages from room ##{room.id} (#{room.name})"
        Rails.logger.info "[AutomatedFeed::Scanner]   - Recent (last 12h): #{recent_count} messages"
        Rails.logger.info "[AutomatedFeed::Scanner]   - Backlog/context: #{old_count} messages"
        Rails.logger.info "[AutomatedFeed::Scanner]   - Already in feed: #{in_feed_count} messages"
        Rails.logger.info "[AutomatedFeed::Scanner]   - Time range: #{oldest_msg&.created_at&.strftime('%Y-%m-%d %H:%M')} to #{newest_msg&.created_at&.strftime('%Y-%m-%d %H:%M')}" if oldest_msg && newest_msg
      else
        Rails.logger.info "[AutomatedFeed::Scanner] Scanning #{messages.size} non-feed messages from last #{@config.lookback_hours} hours"
      end
    end

    def room_scan_message_limit
      limit = if config.respond_to?(:room_scan_message_limit)
                config.room_scan_message_limit
              else
                ENV.fetch("AUTOMATED_FEED_ROOM_SCAN_MESSAGE_LIMIT", "120").to_i
              end

      limit.positive? ? limit : 120
    end

    def room_scan_thread_limit
      limit = if config.respond_to?(:room_scan_thread_limit)
                config.room_scan_thread_limit
              else
                ENV.fetch("AUTOMATED_FEED_ROOM_SCAN_THREAD_LIMIT", "40").to_i
              end

      limit.positive? ? limit : 40
    end

    def room_scan_context_backfill
      backfill = if config.respond_to?(:room_scan_context_backfill)
                   config.room_scan_context_backfill
                 else
                   ENV.fetch("AUTOMATED_FEED_ROOM_SCAN_CONTEXT_BACKFILL", "20").to_i
                 end

      backfill.positive? ? backfill : 20
    end

    def room_scan_lookback_start
      hours = if config.respond_to?(:room_scan_lookback_hours)
                config.room_scan_lookback_hours
              else
                ENV.fetch("AUTOMATED_FEED_ROOM_SCAN_LOOKBACK_HOURS", "12").to_i
              end

      hours = 12 unless hours.positive?
      hours.hours.ago
    end

    def detect_conversations(messages)
      formatted_messages = format_messages_for_ai(messages)
      
      prompt = build_detection_prompt(formatted_messages)
      
      response_format = {
        type: "json_schema",
        json_schema: {
          name: "conversation_detection",
          schema: {
            type: "object",
            properties: {
              conversations: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    message_ids: {
                      type: "array",
                      items: { type: "integer" },
                      description: "Array of message IDs forming one conversation"
                    },
                    title: {
                      type: "string",
                      description: "Proposed title (8-12 words, sentence case)"
                    },
                    summary: {
                      type: "string",
                      description: "Proposed summary (140 characters max, one or two sentences, complete thought)"
                    },
                    participants: {
                      type: "array",
                      items: { type: "string" },
                      description: "Participant usernames"
                    },
                    topic_tags: {
                      type: "array",
                      items: { type: "string" },
                      description: "Topic tags for deduplication"
                    },
                    key_insight: {
                      type: "string",
                      description: "Ultra-short room name (2-4 words, 20 chars max)"
                    },
                    preview_message_id: {
                      type: ["integer", "null"],
                      description: "ID of message that best hooks readers, or null"
                    }
                  },
                  required: ["message_ids", "title", "summary", "participants", "topic_tags", "key_insight", "preview_message_id"]
                }
              }
            },
            required: ["conversations"]
          }
        }
      }

      response = AiGateway.complete(
        prompt: prompt,
        model: @config.ai_model,
        response_format: response_format,
        timeout: 120
      )

      parsed = JSON.parse(response)
      conversations = Array(parsed["conversations"])

      Rails.logger.info "[AutomatedFeed::Scanner] AI detected #{conversations.count} conversations"
      Rails.logger.info "[AutomatedFeed::Scanner] AI response: #{response[0..500]}" if conversations.empty?

      conversations.each_with_object([]) do |conv, detected|
        message_ids = Array(conv["message_ids"]).map(&:to_i)
        
        # For room scans, allow single messages as potential continuations
        # For global scans, require 2+ messages  
        min_messages = room.present? ? 1 : 2
        next if message_ids.length < min_messages
        
        available_message_ids = messages.map(&:id)
        valid_message_ids = message_ids & available_message_ids
        
        if valid_message_ids.length < message_ids.length
          Rails.logger.warn "[AutomatedFeed::Scanner] AI returned invalid message IDs: #{message_ids - valid_message_ids}"
        end
        
        next if valid_message_ids.length < min_messages
        
        selected_messages = messages.select { |m| valid_message_ids.include?(m.id) }

        analysis = ConversationRooms::Validator.analyze(messages: selected_messages, scanned_room: @room)
        unless analysis.valid?
          Rails.logger.info "[AutomatedFeed::Scanner] Skipping conversation: #{analysis.reason}"
          next
        end
        
        # Log the detected conversation with timestamps to help debugging
        msg_timestamps = messages.select { |m| valid_message_ids.include?(m.id) }
                                 .map { |m| m.created_at.strftime('%Y-%m-%d %H:%M') }
        Rails.logger.info "[AutomatedFeed::Scanner] ✓ Detected: \"#{conv["title"]}\" (#{valid_message_ids.length} msgs from #{msg_timestamps.first} to #{msg_timestamps.last})"
        
        detected << {
          message_ids: valid_message_ids,
          title: conv["title"],
          summary: FeedPrompts.truncate_summary(conv["summary"], 140),
          key_insight: conv["key_insight"],
          participants: Array(conv["participants"]),
          topic_tags: Array(conv["topic_tags"]),
          preview_message_id: conv["preview_message_id"]
        }
      end
    rescue AiGateway::Error => e
      Rails.logger.error "[AutomatedFeed::Scanner] AI error: #{e.class} - #{e.message}"
      []
    rescue JSON::ParserError => e
      Rails.logger.error "[AutomatedFeed::Scanner] Failed to parse AI response: #{e.message}"
      []
    end

    def format_messages_for_ai(messages)
      messages.map do |msg|
        thread_context = format_thread_context(msg)
        reactions = format_reactions(msg)
        
        has_attachment = msg.attachment?
        opengraph_embeds = extract_opengraph_embeds(msg)
        
        metadata = []
        metadata << "HAS_ATTACHMENT" if has_attachment
        
        if opengraph_embeds.any?
          og_previews = opengraph_embeds.map { |og| "Link: \"#{og[:title]}\" - #{og[:description]}" }.join("; ")
          metadata << "LINK_PREVIEW: #{og_previews}"
        end
        
        metadata_str = metadata.any? ? "\n  [#{metadata.join(" | ")}]" : ""
        
        "[ID: #{msg.id}] @#{msg.creator.name} (#{format_timestamp(msg.created_at)} in ##{msg.room.name}, #{thread_context}): \"#{msg.plain_text_body}\"#{reactions}#{metadata_str}"
      end.join("\n")
    end

    def format_thread_context(message)
      if message.room.thread? && message.room.parent_message
        "thread-reply-to-#{message.room.parent_message.id}"
      else
        "top-level"
      end
    end

    def format_reactions(message)
      return "" if message.boosts.empty?

      reactions = message.boosts.map { |boost| boost.content.presence || "👍" }.compact
      reactions.any? ? "\nReactions: #{reactions.join(", ")}" : ""
    end

    def format_timestamp(time)
      time.strftime("%Y-%m-%d %H:%M:%S")
    end

    def extract_opengraph_embeds(message)
      return [] unless message.body.body
      
      opengraph_embeds = []
      message.body.body.attachables.each do |attachable|
        if attachable.is_a?(ActionText::Attachment::OpengraphEmbed)
          opengraph_embeds << {
            title: attachable.filename,
            description: attachable.description,
            url: attachable.url,
            href: attachable.href
          }
        end
      end
      opengraph_embeds
    end

    def build_detection_prompt(formatted_messages)
      <<~PROMPT
        You are scanning recent messages from the Small Bets community to identify interesting conversations worth promoting to the Home feed.

        RECENT MESSAGES (last #{@config.lookback_hours} hours, across all rooms):
        #{formatted_messages}

        Thread context values:
        - "top-level" = main room message
        - "thread-reply-to-X" = reply in thread under message X

        NOTE: Messages may include [LINK_PREVIEW] showing the title and description of unfurled links.
        Messages marked with [HAS_ATTACHMENT] have files/images attached.

        CONTEXT:
        Small Bets is a supportive entrepreneurship community where indie founders share wins, ask questions, help each other build profitable projects.

        TASK:
        Identify genuinely interesting conversations from these messages. Be SELECTIVE - we want meaningful conversations that provide value to the community.

        QUALITY CRITERIA (conversation should meet at least ONE):
        
        1. ENGAGEMENT & DEPTH:
           - 4+ messages in back-and-forth discussion
           - OR 3+ different participants discussing
           - OR significant reactions/engagement on messages
        
        2. VALUABLE CONTENT:
           - Specific wins or milestones (with numbers is a plus: "$900 in 3 days", "hit 1000 users")
           - Interesting problems with discussion or solutions
           - Actionable advice or insights being shared
           - Relatable struggles or success stories
           - Interesting questions with substantive answers
        
        3. COMMUNITY VALUE:
           - Other founders would learn from this
           - Sparks meaningful discussion
           - Provides specific insights or experiences

        MINIMUM REQUIREMENTS:
        - For NEW conversations: At least 2 messages with 2 different participants
        - For potential CONTINUATIONS: Single valuable messages ARE allowed (they'll be checked against existing cards)
        - Some substance beyond just small talk

        EXCLUDE:
        - Single message announcements (unless clearly continuing an existing discussion)
        - Pure small talk or banter without substance
        - One-person monologues (unless part of ongoing topic)
        - Very brief exchanges (< 3 messages) unless exceptionally valuable or continuation-worthy

        MESSAGE SELECTION FOR EACH CONVERSATION:
        #{FeedPrompts.conversation_completeness_instructions}

        OUTPUT FORMAT (JSON):
        {
          "conversations": [
            {
              "message_ids": [123, 124, 125, ...],  // INCLUDE ALL messages in the complete conversation
              "title": "Conversation title",
              "summary": "Brief summary",
              "participants": ["@username1", "@username2", ...],
              "topic_tags": ["tag1", "tag2", ...],
              "key_insight": "Short room name",
              "preview_message_id": 123 or null
            }
          ]
        }

        #{FeedPrompts.title_guidelines}

        #{FeedPrompts.summary_guidelines}

        TOPIC TAGS:
        - 2-5 tags that capture the core topic
        - Used for deduplication (e.g., ["snow-removal", "side-hustle", "local-services"])
        - Lowercase, hyphenated

        #{FeedPrompts.key_insight_guidelines}

        #{FeedPrompts.preview_message_guidelines}

        CRITICAL REQUIREMENTS:
        - NEW conversations must have at least 2 messages with 2 participants
        - Single valuable messages CAN be included if they might continue an existing discussion
        - NEVER include conversations without genuine engagement or substance  
        - Only return conversations if they're genuinely valuable to the community
        - If nothing meets the criteria, return empty array: {"conversations": []}
        - Quality over quantity - 1 excellent conversation > 10 mediocre ones
        - Be more selective than you think - we want the homepage to feel curated
        - Return as many quality conversations as you find (no artificial limit)
        - When in doubt, DON'T include it
      PROMPT
    end

    def apply_conversation_cap(conversations)
      limit = config.max_conversations_per_scan
      return conversations unless limit&.positive?

      if conversations.size > limit
        Rails.logger.info "[AutomatedFeed::Scanner] Capping conversations at #{limit} (received #{conversations.size})"
        return conversations.first(limit)
      end

      conversations
    end
  end
end
