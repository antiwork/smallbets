# frozen_string_literal: true

module Stats
  module V2
    # Background job to refresh stats cache
    class RefreshCacheJob < ApplicationJob
      queue_as :stats

      PERIODS = [:today, :month, :year, :all_time].freeze

      def perform
        PERIODS.each do |period|
          Cache::StatsCache.fetch_top_posters(period: period, limit: 10)
        end

        Cache::StatsCache.fetch_system_metrics
        Cache::StatsCache.fetch_top_rooms(limit: 10)

        Rails.logger.info "[STATS V2] Cache refreshed for periods: #{PERIODS.join(', ')}, system metrics, and top rooms"
      end
    end
  end
end
