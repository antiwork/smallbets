# frozen_string_literal: true

module Stats
  module V2
    # Controller for displaying full leaderboards by period
    class TalkersController < BaseController
      VALID_PERIODS = [:today, :month, :year, :all_time].freeze
      LEADERBOARD_LIMIT = 100

      def show
        @period = validate_period
        return unless @period

        load_leaderboard
        load_current_user_rank if Current.user
      end

      private

      def validate_period
        period_param = params[:period]&.to_sym

        unless VALID_PERIODS.include?(period_param)
          redirect_to stats_v2_dashboard_path, alert: "Invalid period"
          return nil
        end

        period_param
      end

      def load_leaderboard
        @users = Queries::TopPostersQuery.call(period: @period, limit: LEADERBOARD_LIMIT)
      end

      def load_current_user_rank
        # If user is in top 100, find their position
        user_in_list = @users.find { |u| u.id == Current.user.id }

        if user_in_list
          @current_user_rank = @users.index(user_in_list) + 1
        else
          # User is not in top 100, calculate their rank
          rank_data = Queries::UserRankQuery.call(user_id: Current.user.id, period: @period)
          @current_user_rank = rank_data if rank_data
        end
      end

      def period_title
        case @period
        when :today then "Today"
        when :month then "This Month"
        when :year then "This Year"
        when :all_time then "All Time"
        end
      end
      helper_method :period_title
    end
  end
end
