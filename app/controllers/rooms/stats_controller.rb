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
      messages_count: StatsService.room_messages_count(@room),
      last_message_at: @room.messages.where(active: true).order(created_at: :desc).first&.created_at
    }

    @top_talkers = StatsService.room_top_talkers(@room, 10)

    if Current.user
      current_user_in_top_10 = @top_talkers.any? { |user| user[:id] == Current.user.id }

      unless current_user_in_top_10
        @current_user_stats = StatsService.room_user_stats(@room, Current.user)

        if @current_user_stats && @current_user_stats.message_count.to_i > 0
          @current_user_rank = StatsService.room_user_rank(@room, Current.user)
          @total_users_in_room = @room.memberships.joins(:user).where(users: { suspended_at: nil, active: true }).count
        end
      end
    end
  end

  private

  def set_room
    @room = Current.user.rooms.find(params[:room_id])
  end
end
