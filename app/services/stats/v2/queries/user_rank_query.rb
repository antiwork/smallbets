# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for calculating user rank
      class UserRankQuery < BaseQuery
        # @param user_id [Integer] User ID
        # @param period [Symbol] time period (:today, :month, :year, :all_time)
        def initialize(user_id:, period:)
          @user_id = user_id
          @period = period
        end

        # Calculate user rank
        # @return [Integer, nil] rank (1-indexed) or nil if user has no messages
        def call
          user = User.find_by(id: @user_id)
          return nil unless user

          user_message_count = fetch_user_message_count
          return nil if user_message_count.nil? || user_message_count == 0

          users_with_more = count_users_with_more_messages(user_message_count)
          users_with_same_earlier = count_users_with_same_messages_earlier_join(user_message_count, user)

          users_with_more + users_with_same_earlier + 1
        end

        private

        def fetch_user_message_count
          result = base_query
            .where("users.id = ?", @user_id)
            .group("users.id")
            .select("COUNT(messages.id) AS message_count")
            .first

          result&.message_count&.to_i
        end

        def count_users_with_more_messages(user_message_count)
          base_query
            .group("users.id")
            .having("COUNT(messages.id) > ?", user_message_count)
            .count
            .size
        end

        def count_users_with_same_messages_earlier_join(user_message_count, user)
          user_join_date = user.membership_started_at || user.created_at

          base_query
            .group("users.id")
            .having("COUNT(messages.id) = ?", user_message_count)
            .where("COALESCE(users.membership_started_at, users.created_at) < ?", user_join_date)
            .count
            .size
        end

        def base_query
          query = User.active_non_suspended
            .joins("INNER JOIN messages ON messages.creator_id = users.id")
            .joins("INNER JOIN rooms ON rooms.id = messages.room_id")
            .where("messages.active = ?", true)
            .where("rooms.type != ?", "Rooms::Direct")

          apply_time_filter(query)
        end

        def apply_time_filter(query)
          time_range = time_range_for_period(@period)
          return query if time_range.nil?

          if @period == :today
            query.where("strftime('%Y-%m-%d', messages.created_at) = ?", today_date_string)
          else
            query.where(messages: { created_at: time_range })
          end
        end
      end
    end
  end
end
