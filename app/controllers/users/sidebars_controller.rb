class Users::SidebarsController < ApplicationController
  DIRECT_PLACEHOLDERS = 10

  def show
    memberships           = Current.user.memberships.visible.without_thread_rooms.with_has_unread_notifications.includes(:room)
    @direct_memberships   = extract_direct_memberships(memberships)
    other_memberships     = memberships.without(@direct_memberships)
    @all_memberships      = other_memberships.with_room_by_sort_preference(Current.user.preference("all_rooms_sort_order"))
    @starred_memberships  = other_memberships.with_room_by_last_active_newest_first

    @direct_memberships.select! { |m| m.room.messages_count > 0 }
    @direct_placeholder_users = find_direct_placeholder_users
  end

  private
    def extract_direct_memberships(all_memberships)
      all_memberships.select { |m| m.room.direct? }.sort_by { |m| m.room.updated_at }.reverse
    end

    def find_direct_placeholder_users
      exclude_user_ids = user_ids_already_in_direct_rooms_with_current_user.including(Current.user.id)
      User.active.where.not(id: exclude_user_ids).order(:created_at).limit([ DIRECT_PLACEHOLDERS - exclude_user_ids.count, 0 ].max)
    end

    def user_ids_already_in_direct_rooms_with_current_user
      Membership.active.where(room_id: Current.user.rooms.directs.pluck(:id)).pluck(:user_id).uniq
    end
end
