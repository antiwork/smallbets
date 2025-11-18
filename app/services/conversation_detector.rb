require_relative "ai_gateway"
require_relative "feed_prompts"

class ConversationDetector
  class Error < StandardError; end
  class NotFoundError < Error; end

  CONTEXT_WINDOW_HOURS = 12
  MAX_CONTEXT_MESSAGES = 100
  MAX_EXPANSION_ITERATIONS = 3

  def self.detect(promoted_message_id:)
    new(promoted_message_id: promoted_message_id).detect
  end

  def initialize(promoted_message_id:)
    @promoted_message_id = promoted_message_id
  end

  def detect
    fetch_promoted_message
    fetch_context_messages
    expand_context_window_iteratively
    generate_title_and_summary
    build_result
  end

  private

  attr_reader :promoted_message_id, :promoted_message, :context_messages, :related_message_ids, :title, :summary, :key_insight, :preview_message_id

  def fetch_promoted_message
    @promoted_message = Message.active
                               .includes(:creator, :room, :boosts)
                               .find(@promoted_message_id)
  rescue ActiveRecord::RecordNotFound
    raise NotFoundError, "Promoted message not found"
  end

  def fetch_context_messages
    room = promoted_message.room
    window_start = promoted_message.created_at - CONTEXT_WINDOW_HOURS.hours
    window_end = promoted_message.created_at + CONTEXT_WINDOW_HOURS.hours

    base_messages = Message.active
                          .where(room: room)
                          .includes(:creator, :room, :boosts)
                          .between(window_start, window_end)
                          .order(:created_at)
                          .limit(MAX_CONTEXT_MESSAGES)
                          .to_a

    if room.thread? && room.parent_message
      base_messages.unshift(room.parent_message) unless base_messages.include?(room.parent_message)
    end

    if promoted_message.threads.any?
      remaining = MAX_CONTEXT_MESSAGES - base_messages.size
      if remaining.positive?
        thread_room_ids = promoted_message.threads.pluck(:id)
        thread_messages = Message.active
                                 .where(room_id: thread_room_ids)
                                 .includes(:creator, :room, :boosts)
                                 .between(window_start, window_end)
                                 .order(:created_at)
                                 .limit(remaining)
        base_messages.concat(thread_messages.to_a)
      end
    end

    @context_messages = base_messages.uniq.sort_by(&:created_at)
  end

  def expand_context_window_iteratively
    format_messages_for_ai
    detect_related_messages
    
    MAX_EXPANSION_ITERATIONS.times do
      break if related_message_ids.empty?
      
      related_messages = context_messages.select { |m| related_message_ids.include?(m.id) }
      break if related_messages.empty?
      
      earliest_message = related_messages.min_by(&:created_at)
      latest_message = related_messages.max_by(&:created_at)
      
      new_window_start = earliest_message.created_at - CONTEXT_WINDOW_HOURS.hours
      new_window_end = latest_message.created_at + CONTEXT_WINDOW_HOURS.hours
      
      current_window_start = context_messages.min_by(&:created_at)&.created_at
      current_window_end = context_messages.max_by(&:created_at)&.created_at
      
      needs_expansion = false
      needs_expansion ||= (current_window_start && new_window_start < current_window_start)
      needs_expansion ||= (current_window_end && new_window_end > current_window_end)
      
      break unless needs_expansion
      
      room = promoted_message.room
      previous_message_ids = context_messages.map(&:id)
      
      expanded_messages = Message.active
                                .where(room: room)
                                .includes(:creator, :room, :boosts)
                                .between(new_window_start, new_window_end)
                                .order(:created_at)
                                .limit(MAX_CONTEXT_MESSAGES)
                                .to_a
      
      if room.thread? && room.parent_message
        expanded_messages.unshift(room.parent_message) unless expanded_messages.include?(room.parent_message)
      end
      
      @context_messages = expanded_messages.uniq.sort_by(&:created_at)
      
      new_message_ids = @context_messages.map(&:id)
      break if (new_message_ids - previous_message_ids).empty?
      
      format_messages_for_ai
      detect_related_messages
    end
  end

  def format_messages_for_ai
    formatted_context = context_messages.map do |msg|
      thread_context = format_thread_context(msg)
      reactions = format_reactions(msg)
      
      "[ID: #{msg.id}] @#{msg.creator.name} (#{format_timestamp(msg.created_at)} in ##{msg.room.name}, #{thread_context}): \"#{msg.plain_text_body}\"#{reactions}"
    end.join("\n")

    promoted_thread_context = format_thread_context(promoted_message)
    promoted_reactions = format_reactions(promoted_message)

    @formatted_prompt = <<~PROMPT
      A moderator promoted this message as interesting:

      PROMOTED MESSAGE:
      [ID: #{promoted_message.id}] @#{promoted_message.creator.name} (#{format_timestamp(promoted_message.created_at)} in ##{promoted_message.room.name}, #{promoted_thread_context}): "#{promoted_message.plain_text_body}"
      #{promoted_reactions}

      CONTEXT (±#{CONTEXT_WINDOW_HOURS} hours in ##{promoted_message.room.name}):
      #{formatted_context}

      Thread context values:
      - "top-level" = main room message
      - "thread-reply-to-X" = reply in thread under message X

      TASK:
      #{FeedPrompts.conversation_completeness_instructions}
      
      OUTPUT FORMAT (JSON):
      {
        "related_message_ids": [123, 124, 125, ...],
        "conversation_flow": "Description of how the conversation evolved from start to finish",
        "reasoning": "Why these messages form one complete conversation, including ALL engaged participants"
      }
    PROMPT

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

  def detect_related_messages
    response_format = {
      type: "json_schema",
      json_schema: {
        name: "conversation_detection",
        schema: {
          type: "object",
          properties: {
            related_message_ids: {
              type: "array",
              items: { type: "integer" },
              description: "Array of message IDs that form a coherent conversation with the promoted message"
            },
            conversation_flow: {
              type: "string",
              description: "Brief description of conversation arc"
            },
            reasoning: {
              type: "string",
              description: "Why these specific messages form one conversation"
            }
          },
          required: ["related_message_ids", "conversation_flow", "reasoning"]
        }
      }
    }

    response = AiGateway.complete(
      prompt: @formatted_prompt,
      response_format: response_format
    )

    parsed = JSON.parse(response)
    detected_ids = Array(parsed["related_message_ids"]).map(&:to_i)
    
    # Ensure promoted message is always included
    detected_ids << promoted_message.id unless detected_ids.include?(promoted_message.id)

    # Filter to only messages we actually have in context
    available_ids = context_messages.map(&:id)
    @related_message_ids = detected_ids.select { |id| available_ids.include?(id) }.uniq.sort
    
    @reasoning = parsed["reasoning"]
    @conversation_flow = parsed["conversation_flow"]
  end

  def generate_title_and_summary
    related_messages = context_messages.select { |m| related_message_ids.include?(m.id) }
    
    conversation_text = related_messages.map do |msg|
      has_attachment = msg.attachment?
      
      opengraph_embeds = extract_opengraph_embeds(msg)
      
      metadata = []
      metadata << "HAS_ATTACHMENT" if has_attachment
      
      if opengraph_embeds.any?
        og_previews = opengraph_embeds.map { |og| "Link: \"#{og[:title]}\" - #{og[:description]}" }.join("; ")
        metadata << "LINK_PREVIEW: #{og_previews}"
      end
      
      metadata_str = metadata.any? ? "\n  [#{metadata.join(" | ")}]" : ""
      
      "[ID: #{msg.id}] @#{msg.creator.name} (#{format_timestamp(msg.created_at)}): \"#{msg.plain_text_body}\"#{metadata_str}"
    end.join("\n")

    title_summary_prompt = <<~PROMPT
      Generate title and summary for this conversation being promoted to the Small Bets community Home.

      CONVERSATION MESSAGES (chronological):
      #{conversation_text}

      NOTE: Messages may include [LINK_PREVIEW] showing the title and description of unfurled links.
      Messages marked with [HAS_ATTACHMENT] have files/images attached.

      CONTEXT:
      Small Bets is a supportive entrepreneurship community where indie founders share wins, ask questions, help each other build profitable projects.

      REQUIREMENTS:

      #{FeedPrompts.title_guidelines}

      #{FeedPrompts.summary_guidelines}

      #{FeedPrompts.key_insight_guidelines}

      #{FeedPrompts.preview_message_guidelines}

      TONE GUIDE:
      - Write like a human, not a corporate blog
      - Conversational and direct - avoid business jargon
      - It's okay to be casual (but not unprofessional)
      - Lead with what's interesting or surprising
      - Specific details beat generic descriptions
      - Think Reddit post or casual Slack message, not press release

      OUTPUT FORMAT (JSON):
      {
        "title": "string (8-12 words, sentence case only)",
        "summary": "string (STRICT: 140 characters max, must not exceed this limit, complete thoughts only, conversational tone)",
        "key_insight": "Ultra-short phrase (2-4 words, 20 characters max)",
        "preview_message_id": number | null
      }
    PROMPT

    response_format = {
      type: "json_schema",
      json_schema: {
        name: "title_summary_generation",
        schema: {
          type: "object",
          properties: {
            title: {
              type: "string",
              description: "Title in 8-12 words"
            },
            summary: {
              type: "string",
              description: "Summary in 140 characters max, one sentence, complete thought",
              maxLength: 140
            },
            key_insight: {
              type: "string",
              description: "Ultra-short phrase in 2-4 words, 20 characters max"
            },
            preview_message_id: {
              type: ["integer", "null"],
              description: "ID of the message that best hooks readers, or null if no good preview exists"
            }
          },
          required: ["title", "summary", "key_insight", "preview_message_id"]
        }
      }
    }

    response = AiGateway.complete(
      prompt: title_summary_prompt,
      response_format: response_format
    )

    parsed = JSON.parse(response)
    @title = parsed["title"]
    @summary = FeedPrompts.truncate_summary(parsed["summary"], 140)
    @key_insight = parsed["key_insight"]
    @preview_message_id = parsed["preview_message_id"]
  end

  def build_result
    {
      message_ids: related_message_ids,
      title: title,
      summary: summary,
      key_insight: key_insight,
      preview_message_id: preview_message_id,
      reasoning: @reasoning,
      conversation_flow: @conversation_flow
    }
  end
end
