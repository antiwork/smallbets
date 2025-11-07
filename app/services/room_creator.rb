class RoomCreator
  class Error < StandardError; end
  class NotFoundError < Error; end
  class InvalidStateError < Error; end

  def self.create_conversation_room(message_ids:, title:, summary:, type:, promoted_by:, key_insight: nil, preview_message_id: nil)
    new(message_ids: message_ids, title: title, summary: summary, type: type, promoted_by: promoted_by, key_insight: key_insight, preview_message_id: preview_message_id).create
  end

  def initialize(message_ids:, title:, summary:, type:, promoted_by:, key_insight: nil, preview_message_id: nil)
    @message_ids = Array(message_ids)
    @title = title
    @summary = summary
    @type = type
    @promoted_by = promoted_by
    @key_insight = key_insight
    @preview_message_id = preview_message_id
  end

  def create
    validate_inputs
    find_messages
    find_source_room

    existing = check_existing_fingerprint
    return existing if existing

    ActiveRecord::Base.transaction do
      conversation_room = create_room
      copy_messages_to_room(conversation_room)
      feed_card = create_feed_card(conversation_room)
      mark_messages_as_in_feed

      { room: conversation_room, feed_card: feed_card }
    end
  end

  private

  attr_reader :message_ids, :title, :summary, :type, :promoted_by, :key_insight, :preview_message_id

  def validate_inputs
    raise InvalidStateError, "Message IDs cannot be empty" if message_ids.empty?
    raise InvalidStateError, "Title is required" if title.blank?
    raise InvalidStateError, "Type must be 'automated' or 'promoted'" unless %w[automated promoted].include?(type)
  end

  def find_messages
    @messages = Message.active.where(id: message_ids).includes(:creator, :boosts, :rich_text_body, :attachment_attachment, :threads).order(:created_at)
    raise NotFoundError, "One or more messages not found" if @messages.count != message_ids.count
  end

  def find_source_room
    analysis = ConversationRooms::Validator.analyze(messages: @messages)

    unless analysis.valid?
      raise InvalidStateError, analysis.reason
    end

    @source_room = analysis.source_room
  end

  def check_existing_fingerprint
    fingerprint = generate_fingerprint
    existing_feed_card = AutomatedFeedCard.find_by(message_fingerprint: fingerprint)
    return { room: existing_feed_card.room, feed_card: existing_feed_card } if existing_feed_card

    @fingerprint = fingerprint
    nil
  end

  def generate_fingerprint
    # Use the actual message IDs that will be copied (explicit message IDs only)
    sorted_ids = message_ids.sort
    Digest::SHA256.hexdigest(sorted_ids.join(","))
  end

  def create_room
    room_name = @key_insight.presence || title

    # For automated feeds without promoted_by, use first message creator
    # For manual promotions, use promoted_by or Current.user
    room_creator = promoted_by || Current.user || @messages.first&.creator

    room = Rooms::Open.create!(
      name: room_name,
      source_room: @source_room,
      creator: room_creator
    )

    copy_memberships_from_source_room(room)
    room
  end

  def copy_messages_to_room(conversation_room)
    @messages.each do |original_message|
      copied_message = conversation_room.messages.create!(
        creator: original_message.creator,
        original_message: original_message,
        created_at: original_message.created_at,
        updated_at: original_message.updated_at,
        client_message_id: original_message.client_message_id,
        body: original_message.body,
        mentions_everyone: original_message.mentions_everyone
      )

      copy_attachment(original_message, copied_message) if original_message.attachment?
      copy_boosts(original_message, copied_message)
    end
  end

  def copy_attachment(original_message, copied_message)
    return unless original_message.attachment.attached?

    begin
      data = original_message.attachment.download
    rescue ActiveStorage::FileNotFoundError => error
      Rails.logger.warn("Skipped copying missing attachment for message #{original_message.id}: #{error.message}")
      Sentry.capture_exception(error, extra: { message_id: original_message.id }) if defined?(Sentry)
      return
    end

    io = StringIO.new(data)
    io.rewind

    copied_message.attachment.attach(
      io: io,
      filename: original_message.attachment.filename,
      content_type: original_message.attachment.content_type
    )

    begin
      copied_message.process_attachment
    rescue ActiveStorage::FileNotFoundError => error
      Rails.logger.warn("Unable to process copied attachment for message #{copied_message.id}: #{error.message}")
      Sentry.capture_exception(error, extra: { message_id: copied_message.id }) if defined?(Sentry)
    end
  end

  def copy_boosts(original_message, copied_message)
    original_message.boosts.each do |boost|
      copied_message.boosts.create!(
        booster: boost.booster,
        content: boost.content,
        created_at: boost.created_at,
        updated_at: boost.updated_at
      )
    end
  end

  def create_feed_card(conversation_room)
    preview_message = nil
    if @preview_message_id.present?
      Rails.logger.info "[RoomCreator] Looking for preview message: #{@preview_message_id}"
      
      # Try to find the preview message in the copied messages by original_message_id
      preview_message = conversation_room.messages.find_by(original_message_id: @preview_message_id)
      Rails.logger.info "[RoomCreator] Found by original_message_id: #{preview_message&.id}"
      
      # Fallback: try by client_message_id if preview is in our message set
      if preview_message.nil?
        original_message = @messages.find { |m| m.id == @preview_message_id }
        Rails.logger.info "[RoomCreator] Original message in @messages: #{original_message&.id}"
        preview_message = conversation_room.messages.find_by(client_message_id: original_message.client_message_id) if original_message
        Rails.logger.info "[RoomCreator] Found by client_message_id: #{preview_message&.id}"
      end
      
      if preview_message.nil?
        Rails.logger.warn "[RoomCreator] Preview message #{@preview_message_id} not found in copied messages (room has #{conversation_room.messages.count} messages)"
        Rails.logger.warn "[RoomCreator] Available original_message_ids: #{conversation_room.messages.pluck(:original_message_id).compact.inspect}"
      else
        Rails.logger.info "[RoomCreator] Preview message set to: #{preview_message.id}"
      end
    end

    AutomatedFeedCard.create!(
      room: conversation_room,
      title: title,
      summary: summary,
      type: type,
      promoted_by_user: promoted_by,
      preview_message: preview_message,
      message_fingerprint: @fingerprint
    )
  end

  def mark_messages_as_in_feed
    @messages.update_all(in_feed: true)
  end

  def copy_memberships_from_source_room(conversation_room)
    # Copy all memberships from the source room to the conversation room
    # This is much more efficient than granting to all users (7800+)
    # and ensures the conversation room has the same access as the source room
    source_members = @source_room.memberships.active
                                  .joins(:user)
                                  .merge(User.active)
                                  .pluck(:user_id, :involvement)
    
    if source_members.any?
      membership_records = source_members.map do |(user_id, involvement)|
        {
          room_id: conversation_room.id,
          user_id: user_id,
          involvement: involvement,
          active: true
        }
      end
      
      Membership.upsert_all(
        membership_records,
        unique_by: %i[room_id user_id]
      )
      
      Rails.logger.info "[RoomCreator] Copied #{source_members.count} memberships from source room #{@source_room.id}"
    end
  end
end
