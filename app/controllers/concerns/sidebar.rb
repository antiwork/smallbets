module Sidebar
  extend ActiveSupport::Concern

  included do
    helper_method :for_each_sidebar_section
  end

  def set_sidebar_memberships
    # Optimize queries by loading only essential data initially
    base_memberships = Current.user.memberships
                               .visible
                               .without_thread_rooms
                               .joins(:room)
                               .where(rooms: { active: true })
                               .includes(:room)

    # Get direct memberships with minimal data
    all_direct_memberships = base_memberships.select { |m| m.room.direct? }
    @direct_memberships = filter_direct_memberships(all_direct_memberships)

    # Get other memberships with minimal data
    other_memberships = base_memberships.reject { |m| m.room.direct? }
    @all_memberships = other_memberships
    @starred_memberships = other_memberships

    @direct_memberships.select! { |m| m.room.messages_count > 0 }
  end

  def for_each_sidebar_section
    [ :starred_rooms, :shared_rooms ].each do |name|
      yield name
    end
  end

  private

  def filter_direct_memberships(direct_memberships)
    # Filter direct memberships to only include:
    # 1. Memberships with unread messages
    # 2. Memberships updated in the last 7 days
    direct_memberships.select do |membership|
      membership.unread? ||
        membership.has_unread_notifications? ||
        (membership.room.updated_at.present? && membership.room.updated_at >= 7.days.ago)
    end.sort_by { |m| m.room.updated_at || Time.at(0) }.reverse
  end
end
