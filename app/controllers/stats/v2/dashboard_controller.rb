# frozen_string_literal: true

module Stats
  module V2
    # Dashboard controller for Stats V2
    # Responsible for displaying the main stats dashboard
    class DashboardController < BaseController
      PERIODS = [:today, :month, :year, :all_time].freeze

      def index
        load_leaderboards
        load_current_user_ranks if Current.user
      end

      private

      def load_leaderboards
        PERIODS.each do |period|
          instance_variable_set(
            "@top_posters_#{period}",
            Queries::TopPostersQuery.call(period: period, limit: 10)
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

        current_user_with_count = Current.user
        current_user_with_count.define_singleton_method(:message_count) { message_count }

        {
          user: current_user_with_count,
          rank: rank,
          message_count: message_count
        }
      end

      def calculate_rank_for_period(period)
        case period
        when :all_time
          StatsService.calculate_all_time_rank(Current.user.id)
        when :today
          StatsService.calculate_today_rank(Current.user.id)
        when :month
          StatsService.calculate_month_rank(Current.user.id)
        when :year
          StatsService.calculate_year_rank(Current.user.id)
        end
      end
    end
  end
end
