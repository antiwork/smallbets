# frozen_string_literal: true

module Stats
  module V2
    module Cache
      # Cache service for Stats V2
      class StatsCache
        CACHE_PREFIX = 'stats'

        class << self
          # Fetch top posters for a period from cache or execute query
          # @param period [Symbol] time period (:today, :month, :year, :all_time)
          # @param limit [Integer] number of results (default: 10)
          # @return [Array] top posters with message_count
          def fetch_top_posters(period:, limit: 10)
            cached_data = Rails.cache.fetch(
              cache_key('top_posters', period, limit),
              expires_in: ttl_for_period(period)
            ) do
              results = Queries::TopPostersQuery.call(period: period, limit: limit)
              serialize_users(results)
            end

            deserialize_users(cached_data)
          end

          # Fetch system metrics from cache or execute query
          # @return [Hash] system metrics
          def fetch_system_metrics
            Rails.cache.fetch(
              cache_key('system_metrics'),
              expires_in: 5.minutes
            ) do
              Queries::SystemMetricsQuery.call
            end
          end

          # Fetch top rooms from cache or execute query
          # @param limit [Integer] number of rooms to return (default: 10)
          # @return [Array] top rooms with message_count
          def fetch_top_rooms(limit: 10)
            cached_data = Rails.cache.fetch(
              cache_key('top_rooms', limit),
              expires_in: 10.minutes
            ) do
              results = Queries::RoomStatsQuery.call(limit: limit)
              serialize_rooms(results)
            end

            deserialize_rooms(cached_data)
          end

          # Clear all Stats cache
          def clear_all
            Rails.cache.delete_matched("#{CACHE_PREFIX}:*")
          end

          # Clear top posters cache for specific period
          # @param period [Symbol] time period to clear
          def clear_top_posters(period: nil)
            if period
              Rails.cache.delete_matched("#{CACHE_PREFIX}:top_posters:#{period}:*")
            else
              Rails.cache.delete_matched("#{CACHE_PREFIX}:top_posters:*")
            end
          end

          # Clear system metrics cache
          def clear_system_metrics
            Rails.cache.delete("#{CACHE_PREFIX}:system_metrics")
          end

          # Clear top rooms cache
          def clear_top_rooms
            Rails.cache.delete_matched("#{CACHE_PREFIX}:top_rooms:*")
          end

          private

          # Serialize users to cacheable format
          def serialize_users(users)
            users.map do |user|
              {
                id: user.id,
                name: user.name,
                message_count: user.message_count.to_i,
                joined_at: user[:joined_at]
              }
            end
          end

          # Deserialize cached data back to User objects with message_count
          def deserialize_users(data)
            user_ids = data.map { |u| u[:id] }
            users_by_id = User.where(id: user_ids).includes(:avatar_attachment).index_by(&:id)

            data.map do |cached_user|
              user = users_by_id[cached_user[:id]]
              next unless user

              message_count = cached_user[:message_count]
              user.define_singleton_method(:message_count) { message_count }
              user
            end.compact
          end

          # Serialize rooms to cacheable format
          def serialize_rooms(rooms)
            rooms.map do |room|
              {
                id: room.id,
                name: room.name,
                type: room.type,
                message_count: room.message_count.to_i
              }
            end
          end

          # Deserialize cached data back to Room objects with message_count
          def deserialize_rooms(data)
            room_ids = data.map { |r| r[:id] }
            rooms_by_id = Room.where(id: room_ids).index_by(&:id)

            data.map do |cached_room|
              room = rooms_by_id[cached_room[:id]]
              next unless room

              message_count = cached_room[:message_count]
              room.define_singleton_method(:message_count) { message_count }
              room
            end.compact
          end

          def cache_key(*parts)
            "#{CACHE_PREFIX}:#{parts.join(':')}"
          end

          def ttl_for_period(period)
            case period.to_sym
            when :today then 1.minute
            when :month then 5.minutes
            when :year then 15.minutes
            when :all_time then 30.minutes
            else 5.minutes
            end
          end
        end
      end
    end
  end
end
