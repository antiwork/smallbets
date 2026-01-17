# frozen_string_literal: true

require "test_helper"

module Stats
  module V2
    module Queries
      class SystemMetricsQueryTest < ActiveSupport::TestCase
        test "returns hash with all required metrics" do
          result = SystemMetricsQuery.call

          assert_kind_of Hash, result
          assert_includes result, :total_users
          assert_includes result, :online_users
          assert_includes result, :total_messages
          assert_includes result, :total_threads
          assert_includes result, :total_boosts
          assert_includes result, :total_posters
          assert_includes result, :database_size
          assert_includes result, :cpu_util
          assert_includes result, :cpu_cores
          assert_includes result, :memory_util_percent
          assert_includes result, :total_memory_gb
          assert_includes result, :disk_util_percent
          assert_includes result, :total_disk_gb
        end

        test "total_users counts only active non-suspended users" do
          active_count = User.where(active: true, suspended_at: nil).count
          result = SystemMetricsQuery.call

          assert_equal active_count, result[:total_users]
        end

        test "online_users counts distinct connected memberships" do
          # Clear any existing connected memberships
          Membership.connected.update_all(connected_at: nil)

          user = users(:david)
          room = rooms(:pets)
          membership = Membership.find_by(user: user, room: room)

          # Connect the membership
          membership.update!(connected_at: Time.current)

          result = SystemMetricsQuery.call
          assert result[:online_users] >= 1
        end

        test "total_messages counts all messages" do
          total_count = Message.count
          result = SystemMetricsQuery.call

          assert_equal total_count, result[:total_messages]
        end

        test "total_threads counts active thread rooms with messages" do
          expected_count = Room.active
            .where(type: "Rooms::Thread")
            .joins(:messages)
            .where("messages.active = ?", true)
            .distinct
            .count

          result = SystemMetricsQuery.call
          assert_equal expected_count, result[:total_threads]
        end

        test "total_boosts counts all boosts" do
          total_count = Boost.count
          result = SystemMetricsQuery.call

          assert_equal total_count, result[:total_boosts]
        end

        test "total_posters counts distinct users with active messages in non-direct rooms" do
          room = rooms(:pets)
          user = users(:david)

          # Ensure user has at least one message
          room.messages.create!(
            creator: user,
            body: "Test message",
            client_message_id: SecureRandom.uuid
          )

          result = SystemMetricsQuery.call
          assert result[:total_posters] >= 1
        end

        test "total_posters excludes direct room messages" do
          # Create a direct room message
          direct_room = rooms(:david_and_jason)
          user = users(:david)

          direct_room.messages.create!(
            creator: user,
            body: "Direct message",
            client_message_id: SecureRandom.uuid
          )

          # Count should not change for direct room messages
          result = SystemMetricsQuery.call

          # Verify the count matches expected behavior
          expected_count = User.active
            .joins(messages: :room)
            .where("rooms.type != ?", "Rooms::Direct")
            .where("messages.active = ?", true)
            .distinct
            .count

          assert_equal expected_count, result[:total_posters]
        end

        test "database_size returns positive integer" do
          result = SystemMetricsQuery.call

          assert result[:database_size].is_a?(Integer)
          assert result[:database_size] >= 0
        end

        test "all metrics return numeric values or nil" do
          result = SystemMetricsQuery.call

          result.each do |key, value|
            assert value.nil? || value.is_a?(Integer) || value.is_a?(Float),
              "Expected #{key} to be numeric or nil, got #{value.class}"
          end
        end

        test "system resource metrics are present or nil" do
          result = SystemMetricsQuery.call

          # CPU metrics
          if result[:cpu_util]
            assert result[:cpu_util].is_a?(Float) || result[:cpu_util].is_a?(Integer)
            assert result[:cpu_util] >= 0 && result[:cpu_util] <= 100
          end

          if result[:cpu_cores]
            assert result[:cpu_cores].is_a?(Integer)
            assert result[:cpu_cores] > 0
          end

          # Memory metrics
          if result[:memory_util_percent]
            assert result[:memory_util_percent].is_a?(Float) || result[:memory_util_percent].is_a?(Integer)
            assert result[:memory_util_percent] >= 0 && result[:memory_util_percent] <= 100
          end

          if result[:total_memory_gb]
            assert result[:total_memory_gb].is_a?(Float) || result[:total_memory_gb].is_a?(Integer)
            assert result[:total_memory_gb] > 0
          end

          # Disk metrics
          if result[:disk_util_percent]
            assert result[:disk_util_percent].is_a?(Integer) || result[:disk_util_percent].is_a?(Float)
            assert result[:disk_util_percent] >= 0 && result[:disk_util_percent] <= 100
          end

          if result[:total_disk_gb]
            assert result[:total_disk_gb].is_a?(Float) || result[:total_disk_gb].is_a?(Integer)
            assert result[:total_disk_gb] > 0
          end
        end
      end
    end
  end
end
