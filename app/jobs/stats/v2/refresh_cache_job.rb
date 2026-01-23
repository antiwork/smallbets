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

        Rails.logger.info "[STATS V2] Cache refreshed for periods: #{PERIODS.join(', ')}"
      end
    end
  end
end
