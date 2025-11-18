require_relative "../../services/ai_gateway"

module AutomatedFeed
  class Deduplicator
    class Error < StandardError; end

    def self.check(conversation:, source_room_id: nil)
      new(conversation: conversation, source_room_id: source_room_id).check
    end

    def initialize(conversation:, source_room_id: nil)
      @conversation = conversation
      @source_room_id = source_room_id
      @config = AutomatedFeed.config
    end

    def check
      level_1_result = check_fingerprint
      return level_1_result if level_1_result[:action] == :skip

      check_topic_similarity
    end

    private

    attr_reader :conversation, :source_room_id, :config

    def check_fingerprint
      sorted_ids = @conversation[:message_ids].sort
      fingerprint = Digest::SHA256.hexdigest(sorted_ids.join(","))

      existing_card = AutomatedFeedCard.find_by(message_fingerprint: fingerprint)
      
      if existing_card
        Rails.logger.info "[AutomatedFeed::Deduplicator] Exact fingerprint match found for feed card #{existing_card.id}"
        return { action: :skip, reason: "exact_fingerprint_match", existing_card: existing_card }
      end

      { action: :continue, fingerprint: fingerprint }
    end

    def check_topic_similarity
      recent_cards = fetch_recent_cards
      return { action: :new_topic } if recent_cards.empty?

      prompt = build_deduplication_prompt(recent_cards)
      
      response_format = {
        type: "json_schema",
        json_schema: {
          name: "deduplication_decision",
          schema: {
            type: "object",
            properties: {
              action: {
                type: "string",
                enum: ["new_topic", "continuation", "duplicate"],
                description: "Action to take"
              },
              related_card_id: {
                type: ["integer", "null"],
                description: "ID of related card if continuation or duplicate"
              },
              similarity_score: {
                type: "number",
                minimum: 0.0,
                maximum: 1.0,
                description: "Similarity score 0.0-1.0"
              },
              reasoning: {
                type: "string",
                description: "Why this decision"
              }
            },
            required: ["action", "related_card_id", "similarity_score", "reasoning"]
          }
        }
      }

      response = AiGateway.complete(
        prompt: prompt,
        model: @config.ai_model,
        response_format: response_format
      )

      parsed = JSON.parse(response)
      action = parsed["action"]
      related_card_id = parsed["related_card_id"]
      reasoning = parsed["reasoning"]
      similarity_score = parsed["similarity_score"].to_f

      case action
      when "new_topic"
        Rails.logger.info "[AutomatedFeed::Deduplicator] New topic detected: #{reasoning}"
        { action: :new_topic, reasoning: reasoning }
      when "continuation"
        if related_card_id
          card = AutomatedFeedCard.find_by(id: related_card_id)
          if card
            Rails.logger.info "[AutomatedFeed::Deduplicator] Continuation detected: card #{card.id} - #{reasoning}"
            { action: :continuation, card: card, reasoning: reasoning, similarity_score: similarity_score }
          else
            Rails.logger.warn "[AutomatedFeed::Deduplicator] Related card #{related_card_id} not found, treating as new topic"
            { action: :new_topic, reasoning: "Related card not found" }
          end
        else
          Rails.logger.warn "[AutomatedFeed::Deduplicator] Continuation without card ID, treating as new topic"
          { action: :new_topic, reasoning: "No card ID provided" }
        end
      when "duplicate"
        if related_card_id
          card = AutomatedFeedCard.find_by(id: related_card_id)
          if card
            Rails.logger.info "[AutomatedFeed::Deduplicator] Duplicate detected: card #{card.id} - #{reasoning}"
            { action: :skip, reason: "duplicate", existing_card: card, reasoning: reasoning }
          else
            Rails.logger.warn "[AutomatedFeed::Deduplicator] Duplicate card #{related_card_id} not found, treating as new topic"
            { action: :new_topic, reasoning: "Duplicate card not found" }
          end
        else
          Rails.logger.warn "[AutomatedFeed::Deduplicator] Duplicate without card ID, treating as new topic"
          { action: :new_topic, reasoning: "No card ID provided" }
        end
      else
        Rails.logger.warn "[AutomatedFeed::Deduplicator] Unknown action '#{action}', treating as new topic"
        { action: :new_topic, reasoning: "Unknown action" }
      end
    rescue AiGateway::Error => e
      Rails.logger.error "[AutomatedFeed::Deduplicator] AI error: #{e.class} - #{e.message}"
      { action: :new_topic, reasoning: "AI error: #{e.message}" }
    rescue JSON::ParserError => e
      Rails.logger.error "[AutomatedFeed::Deduplicator] Failed to parse AI response: #{e.message}"
      { action: :new_topic, reasoning: "Parse error" }
    end

    def fetch_recent_cards
      scope = AutomatedFeedCard.where("feed_cards.updated_at >= ?", 7.days.ago)
                        .includes(:room)
      
      # Filter by source_room_id if provided to only check continuations from the same parent room
      if @source_room_id.present?
        scope = scope.joins(:room).where(rooms: { source_room_id: @source_room_id })
        Rails.logger.info "[AutomatedFeed::Deduplicator] Filtering cards by source_room_id: #{@source_room_id}"
      else
        Rails.logger.info "[AutomatedFeed::Deduplicator] No source_room_id provided, checking all recent cards"
      end
      
      scope.order("feed_cards.updated_at DESC").limit(20)
    end

    def build_deduplication_prompt(recent_cards)
      existing_cards_text = recent_cards.map do |card|
        message_count = card.room.messages.active.count
        hours_since_update = ((Time.current - card.updated_at) / 3600).round(1)
        "[ID: #{card.id}] Title: \"#{card.title}\" | Summary: \"#{card.summary}\" | #{message_count} messages | Last updated: #{hours_since_update}h ago"
      end.join("\n")

      <<~PROMPT
        You detected this new conversation:

        NEW CONVERSATION:
        - Title: "#{@conversation[:title]}"
        - Summary: "#{@conversation[:summary]}"
        - Message IDs: #{@conversation[:message_ids].inspect}
        - Participants: #{@conversation[:participants].inspect}
        - Topic tags: #{@conversation[:topic_tags].inspect}

        EXISTING FEED CARDS (last 7 days, sorted by most recently updated):

        #{existing_cards_text}

        TASK:
        Determine if the new conversation is:

        1. NEW_TOPIC - genuinely different topic, create new card
        2. CONTINUATION - ongoing discussion of existing topic (specify which card ID)
        3. DUPLICATE - same conversation already captured (specify which card ID)

        CONTINUATION CRITERIA:
        - Same core topic as an existing card
        - Overlapping participants (at least 1-2 in common)
        - Natural extension of the previous discussion
        - Updated within the last 3-4 days (not a revival after weeks of silence)

        WHEN MULTIPLE CONTENDERS:
        - Compare every candidate card and pick the SINGLE best match.
        - Favor the card whose title, summary, and topic tags align most closely with the new conversation.
        - Require overlapping participants or very clear topical continuity to choose continuation.
        - Break ties by choosing the card updated most recently.
        - If you are uncertain, choose NEW_TOPIC instead of guessing.

        Be SELECTIVE on CONTINUATION - favor continuation over creating duplicate cards about the same topic.
        Only create NEW_TOPIC if it's truly a different angle or topic.
        If the topic is clearly the same and it's an ongoing discussion, mark as CONTINUATION.

        DUPLICATE CRITERIA:
        - Same conversation already captured (exact same messages or very similar)
        - Overlapping message IDs or nearly identical content

        OUTPUT FORMAT (JSON):
        {
          "action": "new_topic|continuation|duplicate",
          "related_card_id": number or null,
          "similarity_score": 0.0-1.0,
          "reasoning": "Why this decision (1-2 sentences)"
        }
      PROMPT
    end
  end
end
