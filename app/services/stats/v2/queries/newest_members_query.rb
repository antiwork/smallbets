# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for retrieving newest members
      # Returns users ordered by join date (most recent first)
      class NewestMembersQuery < BaseQuery
        # @param limit [Integer] number of members to return (default: 10)
        def initialize(limit: 10)
          @limit = limit
        end

        # Returns newest members with joined_at attribute
        # @return [ActiveRecord::Relation] users with joined_at
        def call
          User
            .select("users.*, COALESCE(users.membership_started_at, users.created_at) as joined_at")
            .where(active: true, suspended_at: nil)
            .order("joined_at DESC")
            .limit(@limit)
        end
      end
    end
  end
end
