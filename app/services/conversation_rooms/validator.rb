module ConversationRooms
  module Validator
    Result = Struct.new(:valid?, :source_room, :reason, keyword_init: true)

    module_function

    def analyze(messages:, scanned_room: nil)
      return Result.new(valid?: false, reason: "No messages provided") if messages.blank?

      rooms = messages.map(&:room).compact.uniq
      return Result.new(valid?: false, reason: "Messages must have associated rooms") if rooms.empty?

      thread_rooms = rooms.select(&:thread?)
      non_thread_rooms = rooms.reject(&:thread?)

      analysis = if thread_rooms.empty?
                   analyze_non_thread_rooms(rooms)
                 else
                   analyze_thread_rooms(thread_rooms, non_thread_rooms)
                 end

      return analysis unless analysis.valid?

      source_room = analysis.source_room

      if scanned_room.present? && source_room.present? && source_room.id != scanned_room.id
        reason = "Threads belong to room #{source_room.id} but scanning room #{scanned_room.id}"
        return Result.new(valid?: false, source_room:, reason: reason)
      end

      Result.new(valid?: true, source_room:, reason: nil)
    end

    def can_combine?(messages:, scanned_room: nil)
      analyze(messages:, scanned_room:).valid?
    end

    def validate!(messages:, scanned_room: nil, error_class: StandardError)
      analysis = analyze(messages:, scanned_room:)
      raise error_class, analysis.reason unless analysis.valid?

      analysis.source_room
    end

    def determine_source_room(messages)
      analyze(messages:, scanned_room: nil).source_room
    end

    def analyze_non_thread_rooms(rooms)
      if rooms.size > 1
        return Result.new(
          valid?: false,
          reason: "Messages must be from the same room or related threads"
        )
      end

      Result.new(valid?: true, source_room: rooms.first)
    end

    def analyze_thread_rooms(thread_rooms, non_thread_rooms)
      parent_rooms = thread_rooms.filter_map { |thread_room| thread_room.parent_message&.room }.uniq

      if parent_rooms.size > 1
        return Result.new(
          valid?: false,
          reason: "Messages from threads with different parent rooms cannot be combined"
        )
      end

      parent_room = parent_rooms.first

      unless parent_room
        return Result.new(
          valid?: false,
          reason: "Thread rooms have no parent message, cannot determine source room"
        )
      end

      if non_thread_rooms.any?
        mismatched_room = non_thread_rooms.find { |room| room.id != parent_room.id }

        if mismatched_room
          return Result.new(
            valid?: false,
            reason: "Messages from non-thread room #{mismatched_room.id} that doesn't match parent room #{parent_room.id} cannot be combined"
          )
        end
      end

      Result.new(valid?: true, source_room: parent_room)
    end
  end
end
