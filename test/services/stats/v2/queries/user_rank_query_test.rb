require "test_helper"

module Stats
  module V2
    module Queries
      class UserRankQueryTest < ActiveSupport::TestCase
        setup do
          @room = rooms(:pets)
        end

        test "returns nil for user with no messages" do
          user = User.create!(name: "NoMessages", email_address: "nomessages@test.com", password: "secret123456", active: true)

          result = UserRankQuery.call(user_id: user.id, period: :all_time)

          assert_nil result
        end

        test "returns nil for non-existent user" do
          result = UserRankQuery.call(user_id: 99999, period: :all_time)

          assert_nil result
        end

        test "calculates rank correctly for all_time period" do
          user1 = users(:jason)
          user2 = users(:david)

          # User1: 3 messages, User2: 1 message
          3.times { @room.messages.create!(creator: user1, body: "Message", client_message_id: SecureRandom.uuid) }
          @room.messages.create!(creator: user2, body: "Message", client_message_id: SecureRandom.uuid)

          result1 = UserRankQuery.call(user_id: user1.id, period: :all_time)
          result2 = UserRankQuery.call(user_id: user2.id, period: :all_time)

          assert_not_nil result1
          assert_not_nil result2
          assert result1[:message_count] > result2[:message_count], "User1 should have more messages than User2"
          assert result1[:rank] < result2[:rank], "User with more messages should have better (lower) rank"
        end

        test "calculates rank correctly for today period" do
          user1 = users(:jason)
          user2 = users(:david)

          # User1: 2 messages today
          2.times { @room.messages.create!(creator: user1, body: "Today", client_message_id: SecureRandom.uuid) }

          # User2: 1 message today
          @room.messages.create!(creator: user2, body: "Today", client_message_id: SecureRandom.uuid)

          result1 = UserRankQuery.call(user_id: user1.id, period: :today)
          result2 = UserRankQuery.call(user_id: user2.id, period: :today)

          assert_not_nil result1
          assert_not_nil result2
          assert result1[:message_count] > result2[:message_count], "User1 should have more messages than User2 today"
          assert result1[:rank] < result2[:rank], "User with more messages should have better (lower) rank"
        end

        test "tiebreaker: earlier join date gets better rank" do
          # Create two new users to ensure clean state
          user1 = User.create!(
            name: "Early User",
            email_address: "early_user@test.com",
            password: "secret123456",
            active: true,
            membership_started_at: 2.days.ago
          )
          user2 = User.create!(
            name: "Late User",
            email_address: "late_user@test.com",
            password: "secret123456",
            active: true,
            membership_started_at: 1.day.ago
          )

          # Both users: 2 messages
          2.times { @room.messages.create!(creator: user1, body: "Message", client_message_id: SecureRandom.uuid) }
          2.times { @room.messages.create!(creator: user2, body: "Message", client_message_id: SecureRandom.uuid) }

          result1 = UserRankQuery.call(user_id: user1.id, period: :all_time)
          result2 = UserRankQuery.call(user_id: user2.id, period: :all_time)

          assert_not_nil result1
          assert_not_nil result2
          assert_equal result1[:message_count], result2[:message_count], "Both users should have equal message count"
          assert result1[:rank] < result2[:rank], "User who joined earlier should have better (lower) rank when message counts are equal"
        end

        test "excludes messages from direct rooms" do
          user = User.create!(name: "TestUser", email_address: "testuser@test.com", password: "secret123456", active: true)
          direct_room = rooms(:david_and_jason)

          # 2 messages in public room
          2.times { @room.messages.create!(creator: user, body: "Public", client_message_id: SecureRandom.uuid) }

          # 5 messages in direct room (should be excluded)
          5.times { direct_room.messages.create!(creator: user, body: "Private", client_message_id: SecureRandom.uuid) }

          result = UserRankQuery.call(user_id: user.id, period: :all_time)

          # Rank should exist based only on public room messages
          assert_not_nil result, "User should have rank based on public messages"
          assert_equal 2, result[:message_count], "Should only count non-direct room messages"
        end

        test "month period filters messages correctly" do
          # Create new user to ensure clean state
          user = User.create!(
            name: "Test User Month",
            email_address: "testmonth@test.com",
            password: "secret123456",
            active: true
          )

          # Last month: 5 messages (created in the past)
          travel_to 1.month.ago do
            5.times { @room.messages.create!(creator: user, body: "Last month", client_message_id: SecureRandom.uuid) }
          end

          # This month: 2 messages (created now)
          travel_to Time.zone.local(2026, 1, 15, 12, 0, 0) do
            2.times { @room.messages.create!(creator: user, body: "This month", client_message_id: SecureRandom.uuid) }

            result = UserRankQuery.call(user_id: user.id, period: :month)

            # Should have rank based on this month's messages
            assert_not_nil result, "User should have rank for this month"
            assert_equal 2, result[:message_count], "Should only count this month's messages"
          end
        end

        test "year period filters messages correctly" do
          # Create new user to ensure clean state
          user = User.create!(
            name: "Test User Year",
            email_address: "testyear@test.com",
            password: "secret123456",
            active: true
          )

          # Last year: 10 messages (created in the past)
          travel_to 1.year.ago do
            10.times { @room.messages.create!(creator: user, body: "Last year", client_message_id: SecureRandom.uuid) }
          end

          # This year: 3 messages (created now)
          travel_to Time.zone.local(2026, 6, 15, 12, 0, 0) do
            3.times { @room.messages.create!(creator: user, body: "This year", client_message_id: SecureRandom.uuid) }

            result = UserRankQuery.call(user_id: user.id, period: :year)

            # Should have rank based on this year's messages
            assert_not_nil result, "User should have rank for this year"
            assert_equal 3, result[:message_count], "Should only count this year's messages"
          end
        end
      end
    end
  end
end
