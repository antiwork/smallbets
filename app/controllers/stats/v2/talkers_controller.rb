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

      def daily_month
        @period = :today
        @from_path = stats_v2_talker_path(period: @period)
        month = params[:month]

        @group = load_month_group(month)
        @previous_month = previous_month_before(month)

        respond_to do |format|
          format.turbo_stream
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
        latest_month = Message.maximum("strftime('%Y-%m', created_at)")
        return @groups = [] unless latest_month

        @groups = [load_month_group(latest_month)].compact
        @previous_month = previous_month_before(latest_month)
      end

      def load_month_group(month)
        Cache::StatsCache.fetch_talkers_breakdown(period: "today:#{month}") do
          days = Message.select("strftime('%Y-%m-%d', created_at) as date")
                        .where("strftime('%Y-%m', created_at) = ?", month)
                        .group("date")
                        .order("date DESC")
                        .map(&:date)

          next [] if days.empty?

          [{
            heading: Date.parse("#{month}-01").strftime("%B %Y"),
            cards: days.sort.reverse.map do |day|
              { title: Date.parse(day).strftime("%A, %B %-d, %Y"),
                users: StatsService.top_posters_for_day(day, BREAKDOWN_LIMIT) }
            end
          }]
        end.first
      end

      def previous_month_before(month)
        Message.where("strftime('%Y-%m', created_at) < ?", month)
               .maximum("strftime('%Y-%m', created_at)")
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
