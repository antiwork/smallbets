# frozen_string_literal: true

module Stats
  module V2
    # Dashboard controller for Stats V2
    # Responsible for displaying the main stats dashboard
    class DashboardController < BaseController
      def index
        @top_posters_all_time = Queries::TopPostersQuery.call(period: :all_time, limit: 10)

        # Get current user rank if they're not in top 10
        if Current.user
          current_user_in_top_10 = @top_posters_all_time.any? { |user| user.id == Current.user.id }

          unless current_user_in_top_10
            user_stats = Queries::TopPostersQuery.call(period: :all_time, limit: 1)
              .where(id: Current.user.id)
              .first

            if user_stats && user_stats.message_count.to_i > 0
              # Calculate rank using existing StatsService for now (will be replaced in Slice 4)
              rank = StatsService.calculate_all_time_rank(Current.user.id)

              # Add message_count to the user object for the view
              current_user_with_count = Current.user
              message_count = user_stats.message_count.to_i
              current_user_with_count.define_singleton_method(:message_count) { message_count }

              @current_user_all_time_rank = {
                user: current_user_with_count,
                rank: rank,
                message_count: message_count
              }
            end
          end
        end
      end
    end
  end
end
