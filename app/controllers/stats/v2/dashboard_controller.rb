# frozen_string_literal: true

module Stats
  module V2
    # Dashboard controller for Stats V2
    # Responsible for displaying the main stats dashboard
    class DashboardController < BaseController
      DEFAULT_LIMIT = 10
      RECENT_HISTORY_DAYS = 7

      def index
        # Just render the shell - turbo frames will lazy load each card
      end

      # Card endpoints for turbo frame lazy loading
      def top_talkers_card
        period = params[:period].to_sym
        load_leaderboard_for_period(period)
        load_current_user_rank_for_period(period) if Current.user

        render partial: 'stats/v2/dashboard/top_talkers_card',
               locals: {
                 period: period,
                 users: instance_variable_get("@top_posters_#{period}"),
                 current_user_rank: instance_variable_get("@current_user_#{period}_rank")
               },
               layout: false
      end

      def system_info_card
        load_system_metrics
        render partial: 'stats/v2/dashboard/system_info',
               locals: { system_metrics: @system_metrics },
               layout: false
      end

      def top_rooms_card
        load_top_rooms
        render partial: 'stats/v2/dashboard/top_rooms',
               locals: { top_rooms: @top_rooms },
               layout: false
      end

      def newest_members_card
        load_newest_members
        render partial: 'stats/v2/dashboard/newest_members',
               locals: { newest_members: @newest_members },
               layout: false
      end

      def message_history_card
        load_message_history
        render partial: 'stats/v2/dashboard/message_history',
               locals: {
                 recent_message_history: @recent_message_history,
                 all_time_message_history: @all_time_message_history
               },
               layout: false
      end

      private

      def load_system_metrics
        @system_metrics = Cache::StatsCache.fetch_system_metrics
      end

      def load_top_rooms
        @top_rooms = Cache::StatsCache.fetch_top_rooms(limit: DEFAULT_LIMIT)
      end

      def load_message_history
        @recent_message_history = Cache::StatsCache.fetch_message_history_recent(limit: RECENT_HISTORY_DAYS)
        @all_time_message_history = Cache::StatsCache.fetch_message_history_all_time
      end

      def load_newest_members
        @newest_members = Cache::StatsCache.fetch_newest_members(limit: DEFAULT_LIMIT)
      end

      def load_leaderboards
        PERIODS.each do |period|
          instance_variable_set(
            "@top_posters_#{period}",
            Cache::StatsCache.fetch_top_posters(period: period, limit: DEFAULT_LIMIT)
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

        rank_data = calculate_rank_for_period(period)
        return nil unless rank_data

        rank = rank_data[:rank]
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

      def load_leaderboard_for_period(period)
        users = Cache::StatsCache.fetch_top_posters(period: period, limit: DEFAULT_LIMIT)
        instance_variable_set("@top_posters_#{period}", users)
      end

      def load_current_user_rank_for_period(period)
        top_posters = instance_variable_get("@top_posters_#{period}")
        rank_data = calculate_user_rank(period, top_posters)
        instance_variable_set("@current_user_#{period}_rank", rank_data) if rank_data
      end
    end
  end
end
