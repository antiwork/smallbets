# frozen_string_literal: true

require "test_helper"

module Stats
  module V2
    module Queries
      class SystemMetricsQueryTest < ActiveSupport::TestCase
        test "returns combined hash from application and system resources queries" do
          result = SystemMetricsQuery.call

          assert_kind_of Hash, result

          # Application metrics
          assert_includes result, :total_users
          assert_includes result, :online_users
          assert_includes result, :total_messages
          assert_includes result, :total_threads
          assert_includes result, :total_boosts
          assert_includes result, :total_posters
          assert_includes result, :database_size

          # System resource metrics
          assert_includes result, :cpu_util
          assert_includes result, :cpu_cores
          assert_includes result, :memory_util_percent
          assert_includes result, :total_memory_gb
          assert_includes result, :disk_util_percent
          assert_includes result, :total_disk_gb
        end

        test "merges results from both queries" do
          result = SystemMetricsQuery.call

          # Verify we have metrics from both sources
          assert result[:total_users].is_a?(Integer)
          assert result[:database_size].is_a?(Integer)

          # System resources may be nil on some systems
          assert result.key?(:cpu_util)
          assert result.key?(:disk_util_percent)
        end
      end
    end
  end
end
