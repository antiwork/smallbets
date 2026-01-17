# frozen_string_literal: true

require "test_helper"

module Stats
  module V2
    module Queries
      class RoomStatsQueryTest < ActiveSupport::TestCase
        test "returns rooms ordered by message count" do
          room1 = rooms(:pets)
          room2 = rooms(:hq)
          user = users(:david)

          # Create different numbers of messages
          2.times do |i|
            room1.messages.create!(
              creator: user,
              body: "Message #{i}",
              client_message_id: SecureRandom.uuid
            )
          end

          5.times do |i|
            room2.messages.create!(
              creator: user,
              body: "Message #{i}",
              client_message_id: SecureRandom.uuid
            )
          end

          result = RoomStatsQuery.call(limit: 10)

          # Find our rooms in results
          room1_result = result.find { |r| r.id == room1.id }
          room2_result = result.find { |r| r.id == room2.id }

          assert room2_result.message_count.to_i > room1_result.message_count.to_i
        end

        test "includes thread messages in count" do
          room = rooms(:pets)
          user = users(:david)

          # Get initial count
          initial_result = RoomStatsQuery.call(limit: 10)
          initial_room = initial_result.find { |r| r.id == room.id }
          initial_count = initial_room&.message_count.to_i || 0

          # Create parent message
          parent_message = room.messages.create!(
            creator: user,
            body: "Parent message",
            client_message_id: SecureRandom.uuid
          )

          # Create thread
          thread = Room.create!(
            type: "Rooms::Thread",
            name: "Thread",
            parent_message: parent_message,
            source_room: room,
            creator: user
          )

          # Create messages in thread
          3.times do |i|
            thread.messages.create!(
              creator: user,
              body: "Thread message #{i}",
              client_message_id: SecureRandom.uuid
            )
          end

          # Re-query
          result = RoomStatsQuery.call(limit: 10)
          room_result = result.find { |r| r.id == room.id }

          # Should count parent + thread messages
          assert room_result.message_count.to_i >= initial_count + 4
        end

        test "only includes open rooms" do
          result = RoomStatsQuery.call(limit: 10)

          # All results should be open rooms
          result.each do |r|
            assert_equal "Rooms::Open", r.type
          end
        end

        test "returns rooms with message_count attribute" do
          result = RoomStatsQuery.call(limit: 10)

          result.each do |room|
            assert room.respond_to?(:message_count)
            assert room.message_count.to_i >= 0
          end
        end

        test "respects limit parameter" do
          result = RoomStatsQuery.call(limit: 5).to_a

          assert result.size <= 5
        end

        test "defaults to limit of 10" do
          query = RoomStatsQuery.new
          result = query.call.to_a

          assert result.size <= 10
        end

        test "orders by message count desc" do
          result = RoomStatsQuery.call(limit: 10).to_a

          # Verify descending order
          if result.size > 1
            result.each_cons(2) do |room1, room2|
              assert room1.message_count.to_i >= room2.message_count.to_i
            end
          end
        end
      end
    end
  end
end
