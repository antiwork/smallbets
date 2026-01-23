# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for room statistics
      # Returns top rooms by message count (includes thread messages)
      class RoomStatsQuery < BaseQuery
        # @param limit [Integer] number of rooms to return (default: 10)
        def initialize(limit: 10)
          @limit = limit
        end

        # Get top rooms by message count
        # @return [ActiveRecord::Relation] rooms with message_count attribute
        def call
          Room.select("rooms.*", message_count_subquery)
            .where(type: "Rooms::Open")
            .group("rooms.id")
            .order("message_count DESC, rooms.created_at ASC")
            .limit(@limit)
        end

        private

        # Subquery to count messages including thread messages
        # Counts both direct messages and messages in threads belonging to this room
        def message_count_subquery
          <<~SQL.squish
            (
              SELECT COUNT(DISTINCT messages.id) FROM messages
              LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'
              LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id
              WHERE messages.active = true AND (messages.room_id = rooms.id OR parent_messages.room_id = rooms.id)
            ) AS message_count
          SQL
        end
      end
    end
  end
end
