require "stringio"

module AutomatedFeed
  class RoomUpdater
    class Error < StandardError; end
    class NotFoundError < Error; end

    def self.update_continuation(feed_card:, new_message_ids:, updated_summary: nil)
      new(feed_card: feed_card, new_message_ids: new_message_ids, updated_summary: updated_summary).update
    end

    def initialize(feed_card:, new_message_ids:, updated_summary: nil)
      @feed_card = feed_card
      @new_message_ids = Array(new_message_ids)
      @updated_summary = updated_summary
      @skipped_message_ids = []
    end

    def update
      validate_inputs
      find_new_messages

      log_skipped_messages

      if @messages.empty?
        update_feed_card_summary_only
        return { room: @feed_card.room, feed_card: @feed_card }
      end

      ActiveRecord::Base.transaction do
        copy_messages_to_room
        update_feed_card
        mark_messages_as_in_feed
      end

      { room: @feed_card.room, feed_card: @feed_card }
    end

    private

    attr_reader :feed_card, :new_message_ids, :updated_summary, :skipped_message_ids

    def validate_inputs
      raise NotFoundError, "Feed card not found" unless @feed_card.present?
      raise Error, "New message IDs cannot be empty" if @new_message_ids.empty?
    end

    def find_new_messages
      existing_message_ids = @feed_card.room.messages.pluck(:original_message_id).compact
      sibling_message_ids = message_ids_in_sibling_conversation_rooms

      combined_existing_ids = (existing_message_ids + sibling_message_ids).uniq
      @skipped_message_ids = new_message_ids & combined_existing_ids
      messages_to_add = new_message_ids - @skipped_message_ids

      @messages = Message.active
                          .where(id: messages_to_add)
                          .includes(:creator, :boosts, :rich_text_body, :attachment_attachment, :threads)
                          .order(:created_at)

      missing_ids = messages_to_add - @messages.pluck(:id)
      raise NotFoundError, "One or more messages not found" if missing_ids.any?
    end

    def copy_messages_to_room
      @messages.each do |original_message|
        existing = @feed_card.room.messages.find_by(original_message_id: original_message.id)
        next if existing

        copied_message = @feed_card.room.messages.create!(
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

    def update_feed_card
      update_params = { updated_at: Time.current }
      update_params[:summary] = @updated_summary if @updated_summary.present?
      
      @feed_card.update!(update_params)
    end

    def update_feed_card_summary_only
      return unless @updated_summary.present?

      @feed_card.update!(summary: @updated_summary)
    end

    def mark_messages_as_in_feed
      @messages.update_all(in_feed: true)
    end

    def message_ids_in_sibling_conversation_rooms
      return [] unless feed_card.room.source_room_id.present?

      sibling_room_ids = Room.where(source_room_id: feed_card.room.source_room_id)
                             .where.not(id: feed_card.room.id)
                             .pluck(:id)

      return [] if sibling_room_ids.empty?

      Message.where(room_id: sibling_room_ids)
             .where.not(original_message_id: nil)
             .pluck(:original_message_id)
             .compact
    end

    def log_skipped_messages
      return if skipped_message_ids.blank?

      Rails.logger.info(
        "[AutomatedFeed::RoomUpdater] Skipped #{skipped_message_ids.size} message(s) already copied to sibling conversation rooms: #{skipped_message_ids.inspect}"
      )
    end
  end
end
