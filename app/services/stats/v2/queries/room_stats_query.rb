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
        # Uses a single aggregation subquery instead of correlated subquery for better performance
        # @return [Array<Room>] rooms with message_count attribute
        def call
          Room.find_by_sql([query_sql, { limit: @limit }])
        end

        private

        # Single aggregation query that computes all room message counts at once
        # then joins with rooms table - avoids per-room subquery execution
        def query_sql
          <<~SQL.squish
            SELECT rooms.*, COALESCE(counts.message_count, 0) AS message_count
            FROM rooms
            LEFT JOIN (
              SELECT
                COALESCE(parent_rooms.id, messages.room_id) AS room_id,
                COUNT(DISTINCT messages.id) AS message_count
              FROM messages
              LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'
              LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id
              LEFT JOIN rooms parent_rooms ON parent_messages.room_id = parent_rooms.id
              WHERE messages.active = true
              GROUP BY COALESCE(parent_rooms.id, messages.room_id)
            ) counts ON counts.room_id = rooms.id
            WHERE rooms.type = 'Rooms::Open'
            ORDER BY message_count DESC, rooms.created_at ASC
            LIMIT :limit
          SQL
        end
      end
    end
  end
end
