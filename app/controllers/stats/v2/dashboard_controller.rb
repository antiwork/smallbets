# frozen_string_literal: true

module Stats
  module V2
    # Dashboard controller for Stats V2
    # Responsible for displaying the main stats dashboard
    class DashboardController < BaseController
      PERIODS = [:today, :month, :year, :all_time].freeze

      def index
        load_system_metrics
        load_leaderboards
        load_current_user_ranks if Current.user
      end

      private

      def load_system_metrics
        @system_metrics = Cache::StatsCache.fetch_system_metrics
      end

      def load_leaderboards
        PERIODS.each do |period|
          instance_variable_set(
            "@top_posters_#{period}",
            Cache::StatsCache.fetch_top_posters(period: period, limit: 10)
          )
        end
      end

      def load_current_user_ranks
        PERIODS.each do |period|
          top_posters = instance_variable_get("@top_posters_#{period}")
          rank_data = calculate_user_rank(period, top_posters)

          instance_variable_set("@current_user_#{period}_rank", rank_data) if rank_data
        end
      end

      def calculate_user_rank(period, top_posters)
        return nil if top_posters.any? { |user| user.id == Current.user.id }

        user_stats = Queries::TopPostersQuery.call(period: period, limit: 1)
          .where(id: Current.user.id)
          .first

        return nil unless user_stats && user_stats.message_count.to_i > 0

        rank = calculate_rank_for_period(period)
        message_count = user_stats.message_count.to_i

        # Create a fresh user instance to avoid singleton method collision
        user_for_display = User.includes(:avatar_attachment).find(Current.user.id)
        user_for_display.define_singleton_method(:message_count) { message_count }

        {
          user: user_for_display,
          rank: rank,
          message_count: message_count
        }
      end

      def calculate_rank_for_period(period)
        Queries::UserRankQuery.call(user_id: Current.user.id, period: period)
      end
    end
  end
end
