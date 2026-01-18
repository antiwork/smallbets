# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for daily message history statistics
      # Returns daily message counts grouped by date
      class MessageHistoryQuery < BaseQuery
        # @param limit [Integer, nil] number of days to return (nil for all-time)
        # @param order [Symbol] sort order (:asc or :desc)
        def initialize(limit: nil, order: :desc)
          @limit = limit
          @order = order
        end

        # Returns daily message counts
        # @return [ActiveRecord::Relation] results with date and count attributes
        def call
          query = Message
            .select("strftime('%Y-%m-%d', created_at) as date", "count(*) as count")
            .where(active: true)
            .group("date")
            .order("date #{@order.to_s.upcase}")

          query = query.limit(@limit) if @limit

          query
        end
      end
    end
  end
end
