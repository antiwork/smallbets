require "test_helper"

module Stats
  module V2
    module Queries
      class TopPostersQueryTest < ActiveSupport::TestCase
        test "returns users ordered by message count descending" do
          room = rooms(:pets)

          # User with 3 messages
          user1 = users(:david)
          3.times { |i| room.messages.create!(creator: user1, body: "Message #{i}", client_message_id: SecureRandom.uuid) }

          # User with 5 messages
          user2 = users(:jason)
          5.times { |i| room.messages.create!(creator: user2, body: "Message #{i}", client_message_id: SecureRandom.uuid) }

          result = TopPostersQuery.call(period: :all_time, limit: 10)

          assert result.first.id == user2.id, "User with most messages should be first"
          assert result.first.message_count >= result.second.message_count, "Should be ordered by message count DESC"
        end

        test "excludes inactive users" do
          room = rooms(:pets)

          inactive_user = User.create!(
            name: "Inactive User",
            email_address: "inactive@example.com",
            password: "secret123456",
            active: false
          )

          room.messages.create!(creator: inactive_user, body: "Test", client_message_id: SecureRandom.uuid)

          result = TopPostersQuery.call(period: :all_time, limit: 10)

          refute_includes result.map(&:id), inactive_user.id
        end

        test "excludes suspended users" do
          room = rooms(:pets)

          suspended_user = User.create!(
            name: "Suspended User",
            email_address: "suspended@example.com",
            password: "secret123456",
            suspended_at: Time.current
          )

          room.messages.create!(creator: suspended_user, body: "Test", client_message_id: SecureRandom.uuid)

          result = TopPostersQuery.call(period: :all_time, limit: 10)

          refute_includes result.map(&:id), suspended_user.id
        end

        test "excludes messages from direct rooms" do
          open_room = rooms(:pets)
          direct_room = rooms(:david_and_jason)

          # Use a fresh user with no existing messages
          user = User.create!(
            name: "Test User",
            email_address: "testuser@example.com",
            password: "secret123456"
          )

          # Messages in open room should count
          2.times { |i| open_room.messages.create!(creator: user, body: "Open #{i}", client_message_id: SecureRandom.uuid) }

          # Messages in direct room should not count
          5.times { |i| direct_room.messages.create!(creator: user, body: "Direct #{i}", client_message_id: SecureRandom.uuid) }

          result = TopPostersQuery.call(period: :all_time, limit: 10)
          user_result = result.find { |u| u.id == user.id }

          assert_equal 2, user_result.message_count, "Should only count messages from non-direct rooms"
        end

        test "filters by today period" do
          room = rooms(:pets)

          # Use a fresh user with no existing messages
          user = User.create!(
            name: "Today Test User",
            email_address: "todaytest@example.com",
            password: "secret123456"
          )

          # Message from today
          room.messages.create!(creator: user, body: "Today", client_message_id: SecureRandom.uuid, created_at: Time.current)

          # Message from yesterday
          room.messages.create!(creator: user, body: "Yesterday", client_message_id: SecureRandom.uuid, created_at: 1.day.ago)

          result = TopPostersQuery.call(period: :today, limit: 10)
          user_result = result.find { |u| u.id == user.id }

          assert_equal 1, user_result&.message_count || 0, "Should only count today's messages"
        end

        test "filters by month period" do
          room = rooms(:pets)

          user = User.create!(
            name: "Month Test User",
            email_address: "monthtest@example.com",
            password: "secret123456"
          )

          # Messages from this month
          2.times do
            room.messages.create!(creator: user, body: "This month", client_message_id: SecureRandom.uuid, created_at: Time.current)
          end

          # Message from last month
          room.messages.create!(creator: user, body: "Last month", client_message_id: SecureRandom.uuid, created_at: 1.month.ago)

          result = TopPostersQuery.call(period: :month, limit: 10)
          user_result = result.find { |u| u.id == user.id }

          assert_equal 2, user_result&.message_count || 0, "Should only count this month's messages"
        end

        test "filters by year period" do
          room = rooms(:pets)

          user = User.create!(
            name: "Year Test User",
            email_address: "yeartest@example.com",
            password: "secret123456"
          )

          # Messages from this year
          3.times do
            room.messages.create!(creator: user, body: "This year", client_message_id: SecureRandom.uuid, created_at: Time.current)
          end

          # Message from last year
          room.messages.create!(creator: user, body: "Last year", client_message_id: SecureRandom.uuid, created_at: 1.year.ago)

          result = TopPostersQuery.call(period: :year, limit: 10)
          user_result = result.find { |u| u.id == user.id }

          assert_equal 3, user_result&.message_count || 0, "Should only count this year's messages"
        end

        test "respects limit parameter" do
          room = rooms(:pets)

          # Create 15 users with messages
          15.times do |i|
            user = User.create!(
              name: "User #{i}",
              email_address: "user#{i}@example.com",
              password: "secret123456"
            )
            room.messages.create!(creator: user, body: "Test", client_message_id: SecureRandom.uuid)
          end

          result = TopPostersQuery.call(period: :all_time, limit: 5)

          assert_equal 5, result.length
        end

        test "tiebreaker uses earlier join date when message counts are equal" do
          room = rooms(:pets)

          # Both users with 2 messages each
          earlier_user = User.create!(
            name: "Earlier User",
            email_address: "earlier@example.com",
            password: "secret123456",
            membership_started_at: 2.days.ago
          )

          later_user = User.create!(
            name: "Later User",
            email_address: "later@example.com",
            password: "secret123456",
            membership_started_at: 1.day.ago
          )

          2.times { room.messages.create!(creator: earlier_user, body: "Test", client_message_id: SecureRandom.uuid) }
          2.times { room.messages.create!(creator: later_user, body: "Test", client_message_id: SecureRandom.uuid) }

          result = TopPostersQuery.call(period: :all_time, limit: 10)

          earlier_index = result.index { |u| u.id == earlier_user.id }
          later_index = result.index { |u| u.id == later_user.id }

          assert earlier_index < later_index, "User who joined earlier should rank higher with equal message count"
        end
      end
    end
  end
end
