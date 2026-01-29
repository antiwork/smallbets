# frozen_string_literal: true

module Stats
  module V2
    # Controller for displaying full leaderboards by period
    class TalkersController < BaseController
      LEADERBOARD_LIMIT = 100
      BREAKDOWN_LIMIT = 10

      def show
        @period = validate_period
        return unless @period

        if @period == :all_time
          load_leaderboard
          load_current_user_rank if Current.user
        else
          load_breakdown
        end
      end

      private

      def validate_period
        period_param = params[:period]&.to_sym

        unless PERIODS.include?(period_param)
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
          @current_user_rank = rank_data[:rank] if rank_data
        end
      end

      def load_breakdown
        case @period
        when :today
          load_daily_breakdown
        when :month
          load_monthly_breakdown
        when :year
          load_yearly_breakdown
        end
      end

      def load_daily_breakdown
        # Only load the current and previous month (matching legacy behavior
        # which lazy-loads one month at a time via infinite scroll)
        current_month = Time.now.utc.strftime("%Y-%m")
        previous_month = 1.month.ago.utc.strftime("%Y-%m")

        days = Message.select("strftime('%Y-%m-%d', created_at) as date")
                      .where("strftime('%Y-%m', created_at) IN (?, ?)", current_month, previous_month)
                      .group("date")
                      .order("date DESC")
                      .map(&:date)

        @days_by_month = days.group_by { |day| day[0..6] } # "YYYY-MM"
        @sorted_months = @days_by_month.keys.sort.reverse

        @daily_stats = {}
        days.each do |day|
          @daily_stats[day] = StatsService.top_posters_for_day(day, BREAKDOWN_LIMIT)
        end
      end

      def load_monthly_breakdown
        months = Message.select("strftime('%Y-%m', created_at) as month")
                        .group("month")
                        .order("month DESC")
                        .map(&:month)

        @months_by_year = months.group_by { |m| m[0..3] } # "YYYY"
        @sorted_years = @months_by_year.keys.sort.reverse

        @monthly_stats = {}
        months.each do |month|
          @monthly_stats[month] = StatsService.top_posters_for_month(month, BREAKDOWN_LIMIT)
        end
      end

      def load_yearly_breakdown
        @years = Message.select("strftime('%Y', created_at) as year")
                        .group("year")
                        .order("year DESC")
                        .map(&:year)

        @yearly_stats = {}
        @years.each do |year|
          @yearly_stats[year] = StatsService.top_posters_for_year(year, BREAKDOWN_LIMIT)
        end
      end
    end
  end
end
