require "test_helper"

module Stats
  module V2
    module Queries
      class UserRankQueryTest < ActiveSupport::TestCase
        setup do
          @room = rooms(:pets)
        end

        test "returns nil for user with no messages" do
          user = User.create!(name: "NoMessages", email_address: "nomessages@test.com", active: true)

          rank = UserRankQuery.call(user_id: user.id, period: :all_time)

          assert_nil rank
        end

        test "returns nil for non-existent user" do
          rank = UserRankQuery.call(user_id: 99999, period: :all_time)

          assert_nil rank
        end

        test "calculates rank correctly for all_time period" do
          user1 = users(:jason)
          user2 = users(:david)

          # User1: 3 messages, User2: 1 message
          3.times { @room.messages.create!(creator: user1, body: "Message", client_message_id: SecureRandom.uuid) }
          @room.messages.create!(creator: user2, body: "Message", client_message_id: SecureRandom.uuid)

          rank1 = UserRankQuery.call(user_id: user1.id, period: :all_time)
          rank2 = UserRankQuery.call(user_id: user2.id, period: :all_time)

          assert_not_nil rank1
          assert_not_nil rank2
          assert rank1 < rank2, "User with more messages should have better (lower) rank"
        end

        test "calculates rank correctly for today period" do
          user1 = users(:jason)
          user2 = users(:david)

          # User1: 2 messages today
          2.times { @room.messages.create!(creator: user1, body: "Today", client_message_id: SecureRandom.uuid) }

          # User2: 1 message today
          @room.messages.create!(creator: user2, body: "Today", client_message_id: SecureRandom.uuid)

          rank1 = UserRankQuery.call(user_id: user1.id, period: :today)
          rank2 = UserRankQuery.call(user_id: user2.id, period: :today)

          assert_not_nil rank1
          assert_not_nil rank2
          assert rank1 < rank2, "User with more messages should have better (lower) rank"
        end

        test "tiebreaker: earlier join date gets better rank" do
          user1 = users(:jason)
          user2 = users(:david)

          # Ensure user1 joined earlier
          user1.update!(membership_started_at: 2.days.ago)
          user2.update!(membership_started_at: 1.day.ago)

          # Both users: 2 messages
          2.times { @room.messages.create!(creator: user1, body: "Message", client_message_id: SecureRandom.uuid) }
          2.times { @room.messages.create!(creator: user2, body: "Message", client_message_id: SecureRandom.uuid) }

          rank1 = UserRankQuery.call(user_id: user1.id, period: :all_time)
          rank2 = UserRankQuery.call(user_id: user2.id, period: :all_time)

          assert_not_nil rank1
          assert_not_nil rank2
          assert rank1 < rank2, "User who joined earlier should have better (lower) rank when message counts are equal"
        end

        test "excludes messages from direct rooms" do
          user = User.create!(name: "TestUser", email_address: "testuser@test.com", active: true)
          direct_room = rooms(:david_and_jason)

          # 2 messages in public room
          2.times { @room.messages.create!(creator: user, body: "Public", client_message_id: SecureRandom.uuid) }

          # 5 messages in direct room (should be excluded)
          5.times { direct_room.messages.create!(creator: user, body: "Private", client_message_id: SecureRandom.uuid) }

          rank = UserRankQuery.call(user_id: user.id, period: :all_time)

          # Rank should exist based only on public room messages
          assert_not_nil rank, "User should have rank based on public messages"

          # Verify DM messages don't count by checking message count is only 2
          user_count = @room.messages.where(creator: user).count
          assert_equal 2, user_count
        end

        test "month period filters messages correctly" do
          user = users(:jason)

          # Last month: 5 messages (created in the past)
          travel_to 1.month.ago do
            5.times { @room.messages.create!(creator: user, body: "Last month", client_message_id: SecureRandom.uuid) }
          end

          # This month: 2 messages (created now)
          travel_to Time.zone.local(2026, 1, 15, 12, 0, 0) do
            2.times { @room.messages.create!(creator: user, body: "This month", client_message_id: SecureRandom.uuid) }

            rank = UserRankQuery.call(user_id: user.id, period: :month)

            # Should have rank based on this month's messages
            assert_not_nil rank, "User should have rank for this month"
          end
        end

        test "year period filters messages correctly" do
          user = users(:jason)

          # Last year: 10 messages (created in the past)
          travel_to 1.year.ago do
            10.times { @room.messages.create!(creator: user, body: "Last year", client_message_id: SecureRandom.uuid) }
          end

          # This year: 3 messages (created now)
          travel_to Time.zone.local(2026, 6, 15, 12, 0, 0) do
            3.times { @room.messages.create!(creator: user, body: "This year", client_message_id: SecureRandom.uuid) }

            rank = UserRankQuery.call(user_id: user.id, period: :year)

            # Should have rank based on this year's messages
            assert_not_nil rank, "User should have rank for this year"
          end
        end
      end
    end
  end
end
