# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for fetching top message posters in a specific room
      # Includes messages from both the main room and any threads within that room
      class RoomTopPostersQuery < BaseQuery
        # @param room_id [Integer] ID of the room to fetch stats for
        # @param limit [Integer] number of top posters to return (default: 10)
        def initialize(room_id:, limit: 10)
          @room_id = room_id
          @limit = limit
        end

        # Execute the query
        # @return [ActiveRecord::Relation] top posters with message_count and joined_at
        def call
          User.active_non_suspended
            .select(
              'users.id',
              'users.name',
              'COUNT(DISTINCT messages.id) AS message_count',
              'COALESCE(users.membership_started_at, users.created_at) as joined_at'
            )
            .joins('INNER JOIN messages ON messages.creator_id = users.id')
            .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
            .joins('LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id')
            .where('messages.room_id = :room_id OR parent_messages.room_id = :room_id', room_id: @room_id)
            .where('messages.active = true')
            .group('users.id', 'users.name', 'users.membership_started_at', 'users.created_at')
            .order('message_count DESC', 'joined_at ASC', 'users.id ASC')
            .limit(@limit)
            .includes(:avatar_attachment)
        end
      end
    end
  end
end
