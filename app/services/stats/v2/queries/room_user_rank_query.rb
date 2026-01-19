# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for calculating user rank within a specific room
      # Includes messages from both the main room and any threads within that room
      class RoomUserRankQuery < BaseQuery
        # @param user_id [Integer] User ID
        # @param room_id [Integer] Room ID
        def initialize(user_id:, room_id:)
          @user_id = user_id
          @room_id = room_id
        end

        # Calculate user rank
        # @return [Hash, nil] hash with :rank and :message_count, or nil if user has no messages
        def call
          user = User.find_by(id: @user_id)
          return nil unless user

          user_message_count = fetch_user_message_count
          return nil if user_message_count.nil? || user_message_count == 0

          users_with_more = count_users_with_more_messages(user_message_count)
          users_with_same_earlier = count_users_with_same_messages_earlier_join(user_message_count, user)

          {
            rank: users_with_more + users_with_same_earlier + 1,
            message_count: user_message_count
          }
        end

        private

        def fetch_user_message_count
          result = base_query
            .where("users.id = ?", @user_id)
            .group("users.id")
            .select("COUNT(DISTINCT messages.id) AS message_count")
            .first

          result&.message_count&.to_i
        end

        def count_users_with_more_messages(user_message_count)
          base_query
            .group("users.id")
            .having("COUNT(DISTINCT messages.id) > ?", user_message_count)
            .count
            .size
        end

        def count_users_with_same_messages_earlier_join(user_message_count, user)
          user_join_date = user.membership_started_at || user.created_at

          base_query
            .group("users.id")
            .having("COUNT(DISTINCT messages.id) = ?", user_message_count)
            .where("COALESCE(users.membership_started_at, users.created_at) < ?", user_join_date)
            .count
            .size
        end

        def base_query
          User.active_non_suspended
            .joins("INNER JOIN messages ON messages.creator_id = users.id")
            .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
            .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
            .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: @room_id)
            .where("messages.active = true")
        end
      end
    end
  end
end
