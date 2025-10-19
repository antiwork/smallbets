class MarketingController < ApplicationController
  include AccountsHelper

  allow_unauthenticated_access
  layout "marketing"

  before_action :restore_authentication, :redirect_signed_in_user_to_chat, except: [ :join, :stats ]

  def show
    @user_count = User.active.non_suspended.count

    # Efficient: Only include users who have posted in the last 90 days
    range_start = 90.days.ago.beginning_of_day
    range_end = Time.now.end_of_day

    recent_user_ids = Message
      .joins(:room)
      .where("messages.active = true")
      .where("rooms.type != ?", "Rooms::Direct")
      .where("messages.created_at >= ? AND messages.created_at <= ?", range_start, range_end)
      .distinct
      .pluck(:creator_id)

    users_with_counts = User
      .select("users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
      .joins(messages: :room)
      .where("rooms.type != ? AND messages.active = true", "Rooms::Direct")
      .where("users.active = true AND users.suspended_at IS NULL")
      .where(id: recent_user_ids)
      .group("users.id, users.name, users.membership_started_at, users.created_at")
      .order("message_count DESC, joined_at ASC, users.id ASC")

    user_ids = users_with_counts.map(&:id)
    users = User.active.without_bots.where(id: user_ids).includes(avatar_attachment: :blob).index_by(&:id)

    top_members_with_avatars = []
    users_with_counts.each do |user|
      real_user = users[user.id]
      if real_user && real_user.avatar.attached?
        top_members_with_avatars << real_user
        break if top_members_with_avatars.size >= 102
      end
    end

    @top_community_members = top_members_with_avatars

    # Build a hash of user_id => { message_count, rank }
    @community_stats_by_user_id = {}
    users_with_counts.each_with_index do |user, idx|
      @community_stats_by_user_id[user.id] = {
        message_count: user.message_count,
        rank: idx + 1
      }
    end
  end

  def join
    redirect_to "https://dvassallo.gumroad.com/l/small-bets/LAST_CHANCE?wanted=true", status: :found, allow_other_host: true
  end

  def stats
    member_count = User.active.non_suspended.count
    online_count = online_users_count
    render json: {
      member_count: member_count,
      online_count: online_count
    }
  end
end
