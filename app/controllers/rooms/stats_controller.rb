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

    # Get top 10 talkers for this room (all time)
    @top_talkers = top_talkers_for_room(@room, 10)

    # Check if current user is in top 10
    if Current.user
      current_user_in_top_10 = @top_talkers.any? { |user| user.id == Current.user.id }

      # If not in top 10, get their stats and rank
      if !current_user_in_top_10
        @current_user_stats = user_stats_for_room(Current.user.id, @room)

        if @current_user_stats && @current_user_stats.message_count.to_i > 0
          @current_user_rank = calculate_user_rank_in_room(Current.user.id, @room)
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

    # Get top talkers for a specific room
    def top_talkers_for_room(room, limit = 10)
      User.select("users.id, users.name, COUNT(DISTINCT messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
          .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true")
          .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
          .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
          .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
          .where("users.active = true AND users.suspended_at IS NULL")
          .group("users.id, users.name, users.membership_started_at, users.created_at")
          .order("message_count DESC, joined_at ASC, users.id ASC")
          .limit(limit)
    end

    # Get user stats for a specific room
    def user_stats_for_room(user_id, room)
      User.select("users.id, users.name, COUNT(DISTINCT messages.id) AS message_count")
          .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true")
          .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
          .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
          .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
          .where("users.id = ?", user_id)
          .group("users.id")
          .first
    end

    # Calculate user rank in a specific room
    def calculate_user_rank_in_room(user_id, room)
      user = User.find_by(id: user_id)
      return nil unless user

      stats = user_stats_for_room(user_id, room)
      return nil unless stats

      # Count users with more messages
      users_with_more_messages = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true")
                                     .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
                                     .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
                                     .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
                                     .where("users.active = true AND users.suspended_at IS NULL")
                                     .group("users.id")
                                     .having("COUNT(DISTINCT messages.id) > ?", stats.message_count.to_i)
                                     .count.size

      # Count users with the same number of messages but earlier join date
      if stats.message_count.to_i > 0
        users_with_same_messages_earlier_join = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true")
                                                    .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
                                                    .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
                                                    .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
                                                    .where("users.active = true AND users.suspended_at IS NULL")
                                                    .group("users.id")
                                                    .having("COUNT(DISTINCT messages.id) = ?", stats.message_count.to_i)
                                                    .where("COALESCE(users.membership_started_at, users.created_at) < ?",
                                                           user.membership_started_at || user.created_at)
                                                    .count.size
      else
        # For users with 0 messages, count users with earlier join date
        users_with_same_messages_earlier_join = User.where("COALESCE(membership_started_at, created_at) < ?",
                                                           user.membership_started_at || user.created_at)
                                                    .where("active = true AND users.suspended_at IS NULL")
                                                    .count
      end

      users_with_more_messages + users_with_same_messages_earlier_join + 1
    end
end
