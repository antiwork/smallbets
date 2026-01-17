# frozen_string_literal: true

require "test_helper"

module Stats
  module V2
    module Queries
      class ApplicationMetricsQueryTest < ActiveSupport::TestCase
        test "returns hash with all application metrics" do
          result = ApplicationMetricsQuery.call

          assert_kind_of Hash, result
          assert_includes result, :total_users
          assert_includes result, :online_users
          assert_includes result, :total_messages
          assert_includes result, :total_threads
          assert_includes result, :total_boosts
          assert_includes result, :total_posters
          assert_includes result, :database_size
        end

        test "all metrics return non-negative integers" do
          result = ApplicationMetricsQuery.call

          result.each do |key, value|
            assert value.is_a?(Integer), "Expected #{key} to be an Integer, got #{value.class}"
            assert value >= 0, "Expected #{key} to be non-negative, got #{value}"
          end
        end

        test "database_size returns positive value" do
          result = ApplicationMetricsQuery.call

          assert result[:database_size] > 0
        end
      end
    end
  end
end
