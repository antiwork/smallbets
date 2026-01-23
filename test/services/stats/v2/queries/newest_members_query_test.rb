# frozen_string_literal: true

require "test_helper"

module Stats
  module V2
    module Queries
      class NewestMembersQueryTest < ActiveSupport::TestCase
        test "returns newest members" do
          result = NewestMembersQuery.call

          assert result.any?
          assert_respond_to result.first, :joined_at
        end

        test "respects limit parameter" do
          result = NewestMembersQuery.call(limit: 3).to_a

          assert_equal 3, result.size
        end

        test "orders by joined_at descending" do
          result = NewestMembersQuery.call.to_a

          joined_dates = result.map(&:joined_at)
          assert_equal joined_dates.sort.reverse, joined_dates
        end

        test "only returns active users" do
          result = NewestMembersQuery.call

          result.each do |user|
            assert user.active, "Expected user #{user.id} to be active"
          end
        end

        test "only returns non-suspended users" do
          result = NewestMembersQuery.call

          result.each do |user|
            assert_nil user.suspended_at, "Expected user #{user.id} to not be suspended"
          end
        end

        test "uses membership_started_at when available" do
          user = users(:david)

          # Update to ensure membership_started_at is set
          user.update!(membership_started_at: 1.day.ago)

          result = NewestMembersQuery.call.to_a
          found_user = result.find { |u| u.id == user.id }

          if found_user
            # joined_at should be close to membership_started_at
            assert_in_delta user.membership_started_at.to_i, found_user.joined_at.to_i, 2.seconds
          end
        end

        test "falls back to created_at when membership_started_at is nil" do
          # Most test fixtures don't have membership_started_at, so they should use created_at
          result = NewestMembersQuery.call.to_a

          result.each do |user|
            full_user = User.find(user.id)
            if full_user.membership_started_at.nil?
              assert_in_delta full_user.created_at.to_i, user.joined_at.to_i, 2.seconds
            end
          end
        end
      end
    end
  end
end
