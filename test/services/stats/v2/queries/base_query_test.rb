require "test_helper"

module Stats
  module V2
    module Queries
      class BaseQueryTest < ActiveSupport::TestCase
        class TestQuery < BaseQuery
          def call
            "test result"
          end
        end

        test "time_range_for_period returns correct range for today" do
          query = TestQuery.new
          range = query.send(:time_range_for_period, :today)

          assert_equal Time.current.beginning_of_day, range.begin
          assert_equal Time.current.end_of_day, range.end
        end

        test "time_range_for_period returns correct range for month" do
          query = TestQuery.new
          range = query.send(:time_range_for_period, :month)

          assert_equal Time.current.beginning_of_month, range.begin
          assert_equal Time.current.end_of_month, range.end
        end

        test "time_range_for_period returns correct range for year" do
          query = TestQuery.new
          range = query.send(:time_range_for_period, :year)

          assert_equal Time.current.beginning_of_year, range.begin
          assert_equal Time.current.end_of_year, range.end
        end

        test "time_range_for_period returns nil for all_time" do
          query = TestQuery.new
          range = query.send(:time_range_for_period, :all_time)

          assert_nil range
        end

        test "time_range_for_period raises ArgumentError for unknown period" do
          query = TestQuery.new

          error = assert_raises(ArgumentError) do
            query.send(:time_range_for_period, :invalid_period)
          end

          assert_match(/Unknown period/, error.message)
        end
      end
    end
  end
end
