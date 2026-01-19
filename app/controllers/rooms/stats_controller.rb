class Rooms::StatsController < ApplicationController
  before_action :set_room

  def show
    @room_stats = {
      name: @room.name,
      created_at: @room.created_at,
      creator: @room.creator,
      access_count: @room.memberships.joins(:user).where(users: { suspended_at: nil, active: true }).count,
      visibility_count: @room.visible_memberships.joins(:user).where(users: { suspended_at: nil, active: true }).count,
      starred_count: @room.memberships.where(involvement: "everything").joins(:user).where(users: { suspended_at: nil, active: true }).count,
      messages_count: all_messages_count_for_room(@room),
      last_message_at: @room.messages.where(active: true).order(created_at: :desc).first&.created_at
    }

    # Get top 10 talkers for this room (all time) using V2 cache
    @top_talkers = Stats::V2::Cache::StatsCache.fetch_room_top_posters(
      room_id: @room.id,
      limit: 10
    )

    # Check if current user is in top 10
    if Current.user
      current_user_in_top_10 = @top_talkers.any? { |user| user.id == Current.user.id }

      # If not in top 10, get their stats and rank
      if !current_user_in_top_10
        rank_data = Stats::V2::Queries::RoomUserRankQuery.call(
          user_id: Current.user.id,
          room_id: @room.id
        )

        if rank_data
          # Create user object with message_count singleton method
          user_for_display = User.includes(:avatar_attachment).find(Current.user.id)
          user_for_display.define_singleton_method(:message_count) { rank_data[:message_count] }

          @current_user_rank = {
            user: user_for_display,
            rank: rank_data[:rank],
            message_count: rank_data[:message_count]
          }

          @total_users_in_room = @room.memberships.joins(:user).where(users: { suspended_at: nil, active: true }).count
        end
      end
    end
  end

  private
    def set_room
      @room = Current.user.rooms.find(params[:room_id])
    end

    # Count messages in a room including messages in threads
    def all_messages_count_for_room(room)
      Message.joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
             .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
             .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
             .active.distinct.count
    end

end
