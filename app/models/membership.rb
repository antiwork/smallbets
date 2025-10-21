class Membership < ApplicationRecord
  include Connectable, Deactivatable

  belongs_to :room
  belongs_to :user

  has_many :unread_notifications, ->(membership) {
    scope = since(membership.unread_at || Time.current)

    if membership.room.direct?
      scope
    else
      scope.left_joins(:mentions)
        .where("mentions.user_id = ? OR messages.mentions_everyone = ?", membership.user_id, true)
        .distinct
    end
  }, through: :room, source: :messages

  scope :with_has_unread_notifications, -> {
    select(
      "memberships.*",

      <<~SQL.squish
      EXISTS (
        SELECT 1
        FROM messages
        WHERE messages.room_id = memberships.room_id
          AND messages.created_at >= COALESCE(
            memberships.unread_at,
            '#{Time.current.utc.iso8601}'
          )
          AND (
            EXISTS (
              SELECT 1
              FROM rooms
              WHERE rooms.id = memberships.room_id
                AND rooms.type = 'Rooms::Direct'
            )
            OR EXISTS (
              SELECT 1
              FROM mentions
              WHERE mentions.message_id = messages.id
                AND mentions.user_id = memberships.user_id
            )
            OR messages.mentions_everyone = true
          )
      ) AS preloaded_has_unread_notifications
    SQL
    )
  }

  after_update_commit { user.reset_remote_connections if deactivated? }
  after_destroy_commit { user.reset_remote_connections }

  enum involvement: %w[ invisible nothing mentions everything ].index_by(&:itself), _prefix: :involved_in

  after_update :broadcast_involvement, if: :saved_change_to_involvement?


  scope :with_ordered_room, -> { includes(:room).joins(:room).order("rooms.sortable_name") }
  scope :with_room_by_activity, -> { includes(:room).joins(:room).order("rooms.messages_count DESC") }
  scope :with_room_by_last_active_newest_first, -> { includes(:room).joins(:room).order("rooms.last_active_at DESC") }
  scope :with_room_chronologically, -> { includes(:room).joins(:room).order("rooms.created_at") }
  scope :with_room_by_sort_preference, ->(preference) {
    case preference
    when "alphabetical"
      with_ordered_room
    when "most_active"
      with_room_by_activity
    else
      with_room_by_last_active_newest_first
    end
  }
  scope :shared, -> { joins(:room).where(rooms: { type: %w[Rooms::Open Rooms::Closed] }) }
  scope :without_direct_rooms, -> { joins(:room).where.not(rooms: { type: "Rooms::Direct" }) }
  scope :without_thread_rooms, -> { joins(:room).where.not(rooms: { type: "Rooms::Thread" }) }

  scope :notifications_on, -> { where(involvement: :everything) }
  scope :visible, -> { where.not(involvement: :invisible) }
  scope :read,  -> { where(unread_at: nil) }
  scope :unread,  -> { where.not(unread_at: nil) }

  def read_until(time)
    return if read? || time < unread_at

    update!(unread_at: room.messages.ordered.where("created_at > ?", time).first&.created_at)
    broadcast_read if read?
  end

  def mark_unread_at(message)
    update!(unread_at: message.created_at)
    broadcast_unread_by_user
  end

  def read
    update!(unread_at: nil)
    broadcast_read
  end

  def read?
    unread_at.blank?
  end

  def unread?
    unread_at.present?
  end

  def has_unread_notifications?
    if attributes.has_key?("preloaded_has_unread_notifications")
      ActiveRecord::Type::Boolean.new.cast(self[:preloaded_has_unread_notifications])
    else
      unread? && unread_notifications.any?
    end
  end

  def receives_mentions?
    involved_in_mentions? || involved_in_everything?
  end

  def ensure_receives_mentions!
    update(involvement: :mentions) unless receives_mentions?
  end

  private

  def broadcast_read
    ActionCable.server.broadcast "user_#{user_id}_reads", { room_id: room_id }
  end

  def broadcast_unread_by_user
    ActionCable.server.broadcast "user_#{user_id}_unreads", { roomId: room.id, roomSize: room.messages_count, roomUpdatedAt: room.last_active_at.iso8601, forceUnread: true }
    ActionCable.server.broadcast "user_#{user_id}_notifications", { roomId: room.id } if has_unread_notifications?
  end

  def broadcast_involvement
    ActionCable.server.broadcast "user_#{user_id}_involvements", { roomId: room_id, involvement: involvement }
  end
end
