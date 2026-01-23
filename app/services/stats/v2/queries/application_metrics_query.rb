# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for application-level metrics (database queries)
      class ApplicationMetricsQuery
        # Get all application metrics
        # @return [Hash] hash with application metrics
        def self.call
          new.call
        end

        def call
          {
            total_users: total_users_count,
            online_users: online_users_count,
            total_messages: total_messages_count,
            total_threads: total_threads_count,
            total_boosts: total_boosts_count,
            total_posters: total_posters_count,
            database_size: database_size
          }
        end

        private

        def total_users_count
          User.where(active: true, suspended_at: nil).count
        end

        def online_users_count
          Membership.connected.select(:user_id).distinct.count
        end

        def total_messages_count
          Message.count
        end

        def total_threads_count
          Room.active
            .where(type: "Rooms::Thread")
            .joins(:messages)
            .where("messages.active = ?", true)
            .distinct
            .count
        end

        def total_boosts_count
          Boost.count
        end

        def total_posters_count
          User.active
            .joins(messages: :room)
            .where("rooms.type != ?", "Rooms::Direct")
            .where("messages.active = ?", true)
            .distinct
            .count
        end

        def database_size
          db_path = ActiveRecord::Base.connection_db_config.configuration_hash[:database]
          File.size(db_path)
        rescue StandardError
          0
        end
      end
    end
  end
end
