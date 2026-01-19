require "test_helper"

module Stats
  module V2
    module Queries
      class RoomUserRankQueryTest < ActiveSupport::TestCase
        setup do
          @room = rooms(:pets)
        end

        test "returns nil for user with no messages in room" do
          user = User.create!(name: "NoMessages", email_address: "nomessages@test.com", password: "secret123456", active: true)

          rank_data = RoomUserRankQuery.call(user_id: user.id, room_id: @room.id)

          assert_nil rank_data
        end

        test "returns nil for non-existent user" do
          rank_data = RoomUserRankQuery.call(user_id: 99999, room_id: @room.id)

          assert_nil rank_data
        end

        test "calculates rank correctly for users in room" do
          user1 = users(:jason)
          user2 = users(:david)

          # User1: 3 messages, User2: 1 message
          3.times { @room.messages.create!(creator: user1, body: "Message", client_message_id: SecureRandom.uuid) }
          @room.messages.create!(creator: user2, body: "Message", client_message_id: SecureRandom.uuid)

          rank_data1 = RoomUserRankQuery.call(user_id: user1.id, room_id: @room.id)
          rank_data2 = RoomUserRankQuery.call(user_id: user2.id, room_id: @room.id)

          assert_not_nil rank_data1
          assert_not_nil rank_data2
          assert_equal 1, rank_data1[:rank], "User with most messages should be rank 1"
          assert_equal 2, rank_data2[:rank], "User with fewer messages should be rank 2"
          assert_equal 3, rank_data1[:message_count]
          assert_equal 1, rank_data2[:message_count]
        end

        test "includes thread messages in count and ranking" do
          user1 = users(:jason)
          user2 = users(:david)

          # User1: 2 messages in main room
          2.times { @room.messages.create!(creator: user1, body: "Message", client_message_id: SecureRandom.uuid) }

          # User2: 1 message in main room + 3 in thread = 4 total
          parent_message = @room.messages.create!(creator: user2, body: "Parent", client_message_id: SecureRandom.uuid)
          thread = Rooms::Thread.create!(
            name: "Test Thread",
            creator: user2,
            parent_message: parent_message
          )
          3.times { thread.messages.create!(creator: user2, body: "Thread message", client_message_id: SecureRandom.uuid) }

          rank_data1 = RoomUserRankQuery.call(user_id: user1.id, room_id: @room.id)
          rank_data2 = RoomUserRankQuery.call(user_id: user2.id, room_id: @room.id)

          assert_equal 2, rank_data1[:rank], "User with 2 messages should be rank 2"
          assert_equal 1, rank_data2[:rank], "User with 4 messages (including threads) should be rank 1"
          assert_equal 4, rank_data2[:message_count]
        end

        test "handles tie-breaking by join date" do
          # Create two users with same message count but different join dates
          early_user = User.create!(
            name: "Early User",
            email_address: "early@example.com",
            password: "secret123456",
            created_at: 2.days.ago
          )

          late_user = User.create!(
            name: "Late User",
            email_address: "late@example.com",
            password: "secret123456",
            created_at: 1.day.ago
          )

          # Give both users the same number of messages
          @room.messages.create!(creator: early_user, body: "Message", client_message_id: SecureRandom.uuid)
          @room.messages.create!(creator: late_user, body: "Message", client_message_id: SecureRandom.uuid)

          early_rank_data = RoomUserRankQuery.call(user_id: early_user.id, room_id: @room.id)
          late_rank_data = RoomUserRankQuery.call(user_id: late_user.id, room_id: @room.id)

          assert early_rank_data[:rank] < late_rank_data[:rank], "User who joined earlier should have better rank with equal message count"
        end

        test "filters by room_id correctly" do
          room2 = rooms(:watercooler)
          user = users(:jason)

          # User has messages in room2 but not in @room
          5.times { room2.messages.create!(creator: user, body: "Message", client_message_id: SecureRandom.uuid) }

          rank_data = RoomUserRankQuery.call(user_id: user.id, room_id: @room.id)

          assert_nil rank_data, "Should return nil when user has no messages in specified room"
        end

        test "excludes inactive users from ranking" do
          active_user = users(:david)
          inactive_user = User.create!(
            name: "Inactive User",
            email_address: "inactive@example.com",
            password: "secret123456",
            active: false
          )

          # Active user: 1 message
          @room.messages.create!(creator: active_user, body: "Message", client_message_id: SecureRandom.uuid)

          # Inactive user: 10 messages (should not affect ranking)
          10.times { @room.messages.create!(creator: inactive_user, body: "Message", client_message_id: SecureRandom.uuid) }

          rank_data = RoomUserRankQuery.call(user_id: active_user.id, room_id: @room.id)

          assert_equal 1, rank_data[:rank], "Active user should be rank 1, inactive users should not count"
        end

        test "excludes suspended users from ranking" do
          active_user = users(:david)
          suspended_user = User.create!(
            name: "Suspended User",
            email_address: "suspended@example.com",
            password: "secret123456",
            suspended_at: Time.current
          )

          # Active user: 1 message
          @room.messages.create!(creator: active_user, body: "Message", client_message_id: SecureRandom.uuid)

          # Suspended user: 10 messages (should not affect ranking)
          10.times { @room.messages.create!(creator: suspended_user, body: "Message", client_message_id: SecureRandom.uuid) }

          rank_data = RoomUserRankQuery.call(user_id: active_user.id, room_id: @room.id)

          assert_equal 1, rank_data[:rank], "Active user should be rank 1, suspended users should not count"
        end
      end
    end
  end
end
