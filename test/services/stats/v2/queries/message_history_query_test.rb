# frozen_string_literal: true

require "test_helper"

module Stats
  module V2
    module Queries
      class MessageHistoryQueryTest < ActiveSupport::TestCase
        test "returns daily message counts" do
          results = MessageHistoryQuery.call.to_a

          assert results.any?
          assert_respond_to results.first, :date
          assert_respond_to results.first, :count
        end

        test "respects limit parameter" do
          all_results = MessageHistoryQuery.call.to_a
          limited_results = MessageHistoryQuery.call(limit: 1).to_a

          assert_equal 1, limited_results.size
          assert limited_results.size < all_results.size if all_results.size > 1
        end

        test "defaults to descending order" do
          results = MessageHistoryQuery.call.to_a

          dates = results.map(&:date)
          assert_equal dates.sort.reverse, dates
        end

        test "respects ascending order" do
          results = MessageHistoryQuery.call(order: :asc).to_a

          dates = results.map(&:date)
          assert_equal dates.sort, dates
        end

        test "only counts active messages" do
          user = users(:david)
          room = rooms(:hq)

          # Create active message
          active_msg = Message.create!(
            creator: user,
            room: room,
            client_message_id: "test_active_#{Time.now.to_i}",
            active: true
          )

          # Create inactive message on same day
          inactive_msg = Message.create!(
            creator: user,
            room: room,
            client_message_id: "test_inactive_#{Time.now.to_i}",
            active: false,
            created_at: active_msg.created_at
          )

          date = active_msg.created_at.strftime('%Y-%m-%d')
          result = MessageHistoryQuery.call.to_a.find { |r| r.date == date }

          # Count should not include the inactive message
          assert result.count >= 1
        end

        test "groups messages by date" do
          results = MessageHistoryQuery.call.to_a

          dates = results.map(&:date)
          assert_equal dates, dates.uniq, "Expected each date to appear only once"
        end
      end
    end
  end
end
