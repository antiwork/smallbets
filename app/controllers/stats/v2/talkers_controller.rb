# frozen_string_literal: true

module Stats
  module V2
    # Controller for displaying full leaderboards by period
    class TalkersController < BaseController
      BREAKDOWN_LIMIT = 10

      def show
        @period = validate_period
        return unless @period

        @from_path = stats_v2_talker_path(period: @period)

        if @period == :all_time
          load_leaderboard
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
        @users = Cache::StatsCache.fetch_top_posters(period: @period, limit: nil)
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
        @groups = Cache::StatsCache.fetch_talkers_breakdown(period: :today) do
          # Only load the current and previous month (matching legacy behavior
          # which lazy-loads one month at a time via infinite scroll)
          current_month = Time.now.utc.strftime("%Y-%m")
          previous_month = 1.month.ago.utc.strftime("%Y-%m")

          days = Message.select("strftime('%Y-%m-%d', created_at) as date")
                        .where("strftime('%Y-%m', created_at) IN (?, ?)", current_month, previous_month)
                        .group("date")
                        .order("date DESC")
                        .map(&:date)

          days_by_month = days.group_by { |day| day[0..6] }

          days_by_month.keys.sort.reverse.map do |month_key|
            {
              heading: Date.parse("#{month_key}-01").strftime("%B %Y"),
              cards: days_by_month[month_key].sort.reverse.map do |day|
                { title: Date.parse(day).strftime("%A, %B %-d, %Y"),
                  users: StatsService.top_posters_for_day(day, BREAKDOWN_LIMIT) }
              end
            }
          end
        end
      end

      def load_monthly_breakdown
        @groups = Cache::StatsCache.fetch_talkers_breakdown(period: :month) do
          months = Message.select("strftime('%Y-%m', created_at) as month")
                          .group("month")
                          .order("month DESC")
                          .map(&:month)

          months_by_year = months.group_by { |m| m[0..3] }

          months_by_year.keys.sort.reverse.map do |year|
            {
              heading: year,
              cards: months_by_year[year].sort.reverse.map do |month|
                { title: Date.parse("#{month}-01").strftime("%B %Y"),
                  users: StatsService.top_posters_for_month(month, BREAKDOWN_LIMIT) }
              end
            }
          end
        end
      end

      def load_yearly_breakdown
        @groups = Cache::StatsCache.fetch_talkers_breakdown(period: :year) do
          years = Message.select("strftime('%Y', created_at) as year")
                         .group("year")
                         .order("year DESC")
                         .map(&:year)

          [{
            heading: nil,
            cards: years.map do |year|
              { title: year,
                users: StatsService.top_posters_for_year(year, BREAKDOWN_LIMIT) }
            end
          }]
        end
      end
    end
  end
end
