# frozen_string_literal: true

module Stats
  module V2
    # Background job to refresh stats cache
    class RefreshCacheJob < ApplicationJob
      queue_as :stats

      PERIODS = [:today, :month, :year, :all_time].freeze
      DEFAULT_LIMIT = 10

      def perform
        PERIODS.each do |period|
          Cache::StatsCache.fetch_top_posters(period: period, limit: DEFAULT_LIMIT)
        end

        Cache::StatsCache.fetch_system_metrics
        Cache::StatsCache.fetch_top_rooms(limit: DEFAULT_LIMIT)

        Rails.logger.info "[STATS V2] Cache refreshed for periods: #{PERIODS.join(', ')}, system metrics, and top rooms"
      end
    end
  end
end
