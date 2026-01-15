# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for fetching top message posters
      class TopPostersQuery < BaseQuery
        # @param period [Symbol] time period (:today, :month, :year, :all_time)
        # @param limit [Integer] number of top posters to return (default: 10)
        def initialize(period:, limit: 10)
          @period = period
          @limit = limit
        end

        # Execute the query
        # @return [ActiveRecord::Relation] top posters with message_count and joined_at
        def call
          query = User.active_non_suspended
            .select(
              'users.id',
              'users.name',
              'COUNT(messages.id) AS message_count',
              'COALESCE(users.membership_started_at, users.created_at) as joined_at'
            )
            .joins('INNER JOIN messages ON messages.creator_id = users.id')
            .merge(Message.active.in_non_direct_rooms)
            .group('users.id', 'users.name', 'users.membership_started_at', 'users.created_at')
            .order('message_count DESC', 'joined_at ASC', 'users.id ASC')
            .limit(@limit)
            .includes(:avatar_attachment)

          apply_time_filter(query)
        end

        private

        # Apply time filtering based on period
        # @param query [ActiveRecord::Relation] base query to filter
        # @return [ActiveRecord::Relation] filtered query
        def apply_time_filter(query)
          time_range = time_range_for_period(@period)
          return query if time_range.nil?

          if @period == :today
            # Use strftime for SQLite optimization on today queries
            query.where("strftime('%Y-%m-%d', messages.created_at) = ?", today_date_string)
          else
            query.where(messages: { created_at: time_range })
          end
        end
      end
    end
  end
end
