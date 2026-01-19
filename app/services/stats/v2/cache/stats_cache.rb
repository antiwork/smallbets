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

          # Fetch recent message history from cache or execute query
          # @param limit [Integer] number of days to return (default: 7)
          # @return [Array<Hash>] recent daily message counts with date and count
          def fetch_message_history_recent(limit: 7)
            Rails.cache.fetch(
              cache_key('message_history', 'recent', limit),
              expires_in: 5.minutes
            ) do
              serialize_message_history(Queries::MessageHistoryQuery.call(limit: limit, order: :desc))
            end
          end

          # Fetch all-time message history from cache or execute query
          # @return [Array<Hash>] all-time daily message counts with date and count
          def fetch_message_history_all_time
            Rails.cache.fetch(
              cache_key('message_history', 'all_time'),
              expires_in: 15.minutes
            ) do
              serialize_message_history(Queries::MessageHistoryQuery.call(order: :asc))
            end
          end

          # Fetch newest members from cache or execute query
          # @param limit [Integer] number of members to return (default: 10)
          # @return [Array] newest members with joined_at
          def fetch_newest_members(limit: 10)
            cached_data = Rails.cache.fetch(
              cache_key('newest_members', limit),
              expires_in: 10.minutes
            ) do
              results = Queries::NewestMembersQuery.call(limit: limit)
              serialize_newest_members(results)
            end

            deserialize_newest_members(cached_data)
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

          # Clear message history cache
          def clear_message_history
            Rails.cache.delete_matched("#{CACHE_PREFIX}:message_history:*")
          end

          # Clear newest members cache
          def clear_newest_members
            Rails.cache.delete_matched("#{CACHE_PREFIX}:newest_members:*")
          end

          # Fetch top posters for a specific room from cache or execute query
          # @param room_id [Integer] room ID
          # @param limit [Integer] number of results (default: 10)
          # @return [Array] top posters with message_count
          def fetch_room_top_posters(room_id:, limit: 10)
            cached_data = Rails.cache.fetch(
              cache_key('room_top_posters', room_id, limit),
              expires_in: 5.minutes
            ) do
              results = Queries::RoomTopPostersQuery.call(room_id: room_id, limit: limit)
              serialize_users(results)
            end

            deserialize_users(cached_data)
          end

          # Clear cache for specific room stats
          # @param room_id [Integer] room ID to clear cache for
          def clear_room_stats(room_id:)
            Rails.cache.delete_matched("#{CACHE_PREFIX}:room_top_posters:#{room_id}:*")
          end

          # Clear cache for all room stats
          def clear_all_room_stats
            Rails.cache.delete_matched("#{CACHE_PREFIX}:room_top_posters:*")
          end

          # Fetch user stats (rank and message count) from cache or execute query
          # @param user_id [Integer] user ID
          # @param period [Symbol] time period (:today, :month, :year, :all_time)
          # @return [Hash, nil] hash with :rank and :message_count keys, or nil if no messages
          def fetch_user_stats(user_id:, period: :all_time)
            Rails.cache.fetch(
              cache_key('user_stats', user_id, period),
              expires_in: ttl_for_period(period)
            ) do
              Queries::UserRankQuery.call(user_id: user_id, period: period)
            end
          end

          # Clear cache for specific user stats
          # @param user_id [Integer] user ID to clear cache for
          # @param period [Symbol, nil] specific period to clear, or nil for all periods
          def clear_user_stats(user_id:, period: nil)
            if period
              Rails.cache.delete(cache_key('user_stats', user_id, period))
            else
              Rails.cache.delete_matched("#{CACHE_PREFIX}:user_stats:#{user_id}:*")
            end
          end

          # Clear cache for all user stats
          def clear_all_user_stats
            Rails.cache.delete_matched("#{CACHE_PREFIX}:user_stats:*")
          end

          private

          # Generic serializer for entities with message_count
          # @param entities [ActiveRecord::Relation] entities to serialize
          # @param attributes [Array<Symbol>] additional attributes to cache
          # @return [Array<Hash>] serialized data
          def serialize_entities(entities, *attributes)
            entities.map do |entity|
              base = { id: entity.id, message_count: entity.message_count.to_i }
              attributes.each do |attr|
                base[attr] = entity[attr] || entity.send(attr)
              end
              base
            end
          end

          # Generic deserializer for entities with a singleton attribute
          # @param data [Array<Hash>] cached data to deserialize
          # @param model_class [Class] ActiveRecord model class
          # @param includes [Symbol, Array] associations to eager load
          # @param singleton_attr [Symbol] attribute to define as singleton method (default: :message_count)
          # @return [Array<ActiveRecord::Base>] deserialized entities with singleton attribute
          def deserialize_entities(data, model_class, includes: [], singleton_attr: :message_count)
            ids = data.map { |e| e[:id] }
            query = model_class.where(id: ids)
            query = query.includes(includes) if includes.present?
            entities_by_id = query.index_by(&:id)

            data.map do |cached_entity|
              entity = entities_by_id[cached_entity[:id]]
              next unless entity

              attr_value = cached_entity[singleton_attr]
              entity.define_singleton_method(singleton_attr) { attr_value }
              entity
            end.compact
          end

          # Serialize users to cacheable format
          def serialize_users(users)
            serialize_entities(users, :name, :joined_at)
          end

          # Deserialize cached data back to User objects with message_count
          def deserialize_users(data)
            deserialize_entities(data, User, includes: :avatar_attachment)
          end

          # Serialize rooms to cacheable format
          def serialize_rooms(rooms)
            serialize_entities(rooms, :name, :type)
          end

          # Deserialize cached data back to Room objects with message_count
          def deserialize_rooms(data)
            deserialize_entities(data, Room)
          end

          # Serialize message history query results to cacheable format
          def serialize_message_history(results)
            results.to_a.map do |result|
              { date: result.date, count: result.count.to_i }
            end
          end

          # Serialize newest members to cacheable format
          def serialize_newest_members(users)
            users.map do |user|
              { id: user.id, name: user.name, joined_at: user.joined_at }
            end
          end

          # Deserialize cached data back to User objects with joined_at
          def deserialize_newest_members(data)
            deserialize_entities(data, User, includes: :avatar_attachment, singleton_attr: :joined_at)
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
