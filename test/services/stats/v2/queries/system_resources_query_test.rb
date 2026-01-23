# frozen_string_literal: true

require "test_helper"

module Stats
  module V2
    module Queries
      class SystemResourcesQueryTest < ActiveSupport::TestCase
        test "returns hash with all resource metrics" do
          result = SystemResourcesQuery.call

          assert_kind_of Hash, result
          assert_includes result, :cpu_util
          assert_includes result, :cpu_cores
          assert_includes result, :memory_util_percent
          assert_includes result, :total_memory_gb
          assert_includes result, :disk_util_percent
          assert_includes result, :total_disk_gb
        end

        test "cpu metrics are valid when present" do
          result = SystemResourcesQuery.call

          if result[:cpu_util]
            assert result[:cpu_util].is_a?(Float) || result[:cpu_util].is_a?(Integer)
            assert result[:cpu_util] >= 0 && result[:cpu_util] <= 100
          end

          if result[:cpu_cores]
            assert result[:cpu_cores].is_a?(Integer)
            assert result[:cpu_cores] > 0
          end
        end

        test "memory metrics are valid when present" do
          result = SystemResourcesQuery.call

          if result[:memory_util_percent]
            assert result[:memory_util_percent].is_a?(Float) || result[:memory_util_percent].is_a?(Integer)
            assert result[:memory_util_percent] >= 0 && result[:memory_util_percent] <= 100
          end

          if result[:total_memory_gb]
            assert result[:total_memory_gb].is_a?(Float) || result[:total_memory_gb].is_a?(Integer)
            assert result[:total_memory_gb] > 0
          end
        end

        test "disk metrics are valid when present" do
          result = SystemResourcesQuery.call

          if result[:disk_util_percent]
            assert result[:disk_util_percent].is_a?(Integer) || result[:disk_util_percent].is_a?(Float)
            assert result[:disk_util_percent] >= 0 && result[:disk_util_percent] <= 100
          end

          if result[:total_disk_gb]
            assert result[:total_disk_gb].is_a?(Float) || result[:total_disk_gb].is_a?(Integer)
            assert result[:total_disk_gb] > 0
          end
        end
      end
    end
  end
end
