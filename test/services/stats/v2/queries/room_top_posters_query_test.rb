require "test_helper"

module Stats
  module V2
    module Queries
      class RoomTopPostersQueryTest < ActiveSupport::TestCase
        test "returns users ordered by message count descending for specific room" do
          room1 = rooms(:pets)
          room2 = rooms(:watercooler)

          # User with 3 messages in room1
          user1 = users(:david)
          3.times { |i| room1.messages.create!(creator: user1, body: "Message #{i}", client_message_id: SecureRandom.uuid) }

          # User with 5 messages in room1
          user2 = users(:jason)
          5.times { |i| room1.messages.create!(creator: user2, body: "Message #{i}", client_message_id: SecureRandom.uuid) }

          # User with messages in different room (should not appear)
          user3 = User.create!(name: "Other User", email_address: "other@example.com", password: "secret123456")
          10.times { |i| room2.messages.create!(creator: user3, body: "Message #{i}", client_message_id: SecureRandom.uuid) }

          result = RoomTopPostersQuery.call(room_id: room1.id, limit: 10).to_a

          assert_equal 2, result.size
          assert_equal user2.id, result.first.id, "User with most messages should be first"
          refute_includes result.map(&:id), user3.id, "Should not include users from other rooms"
        end

        test "includes thread messages in count" do
          room = rooms(:pets)
          user = users(:david)

          # Create messages in main room
          2.times { |i| room.messages.create!(creator: user, body: "Message #{i}", client_message_id: SecureRandom.uuid) }

          # Create a thread and add messages
          parent_message = room.messages.first
          thread = Rooms::Thread.create!(
            name: "Test Thread",
            creator: user,
            parent_message: parent_message
          )
          3.times { |i| thread.messages.create!(creator: user, body: "Thread message #{i}", client_message_id: SecureRandom.uuid) }

          result = RoomTopPostersQuery.call(room_id: room.id, limit: 10)

          user_result = result.find { |u| u.id == user.id }
          assert_equal 5, user_result.message_count.to_i, "Should count both room and thread messages"
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

          result = RoomTopPostersQuery.call(room_id: room.id, limit: 10)

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

          result = RoomTopPostersQuery.call(room_id: room.id, limit: 10)

          refute_includes result.map(&:id), suspended_user.id
        end

        test "excludes inactive messages" do
          room = rooms(:pets)
          user = users(:david)

          active_message = room.messages.create!(creator: user, body: "Active", client_message_id: SecureRandom.uuid)
          inactive_message = room.messages.create!(creator: user, body: "Inactive", client_message_id: SecureRandom.uuid, active: false)

          result = RoomTopPostersQuery.call(room_id: room.id, limit: 10)

          user_result = result.find { |u| u.id == user.id }
          assert_equal 1, user_result.message_count.to_i, "Should only count active messages"
        end

        test "respects limit parameter" do
          room = rooms(:pets)

          # Create 15 users with messages
          users = []
          15.times do |i|
            user = User.create!(
              name: "User #{i}",
              email_address: "user#{i}@example.com",
              password: "secret123456"
            )
            users << user
          end

          # Give each user at least one message
          users.each do |user|
            room.messages.create!(creator: user, body: "Message", client_message_id: SecureRandom.uuid)
          end

          result = RoomTopPostersQuery.call(room_id: room.id, limit: 10).to_a

          assert result.size <= 10, "Should respect limit parameter"
        end

        test "uses earlier join date as tiebreaker when message counts are equal" do
          room = rooms(:pets)

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
          room.messages.create!(creator: early_user, body: "Message", client_message_id: SecureRandom.uuid)
          room.messages.create!(creator: late_user, body: "Message", client_message_id: SecureRandom.uuid)

          result = RoomTopPostersQuery.call(room_id: room.id, limit: 10)

          early_index = result.index { |u| u.id == early_user.id }
          late_index = result.index { |u| u.id == late_user.id }

          assert early_index < late_index, "User who joined earlier should be ranked higher with equal message count"
        end

        test "returns empty array when no messages in room" do
          room = rooms(:pets)

          result = RoomTopPostersQuery.call(room_id: room.id, limit: 10)

          assert_equal [], result.to_a
        end

        test "uses DISTINCT count for accuracy" do
          room = rooms(:pets)
          user = users(:david)

          # Create messages that might be duplicated in joins
          3.times { |i| room.messages.create!(creator: user, body: "Message #{i}", client_message_id: SecureRandom.uuid) }

          result = RoomTopPostersQuery.call(room_id: room.id, limit: 10)

          user_result = result.find { |u| u.id == user.id }
          assert_equal 3, user_result.message_count.to_i, "Should use DISTINCT count"
        end
      end
    end
  end
end
