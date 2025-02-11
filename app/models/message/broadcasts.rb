module Message::Broadcasts
  def broadcast_create
    broadcast_append_to room, :messages, target: [ room, :messages ], partial: "messages/message", locals: { current_room: room }
    ActionCable.server.broadcast("unread_rooms", { roomId: room.id, roomSize: room.messages_count, roomUpdatedAt: created_at.iso8601 })

    broadcast_notifications
  end

  def broadcast_update
    broadcast_notifications(ignore_if_older_message: true)
  end

  def broadcast_notifications(ignore_if_older_message: false)
    memberships = room.memberships.where(user_id: mentionee_ids)

    memberships.each do |membership|
      next if ignore_if_older_message && (membership.read? || membership.unread_at > created_at)

      ActionCable.server.broadcast "user_#{membership.user_id}_notifications", { roomId: room.id }
    end
  end

  def broadcast_reactivation
    previous_message = room.messages.active.order(:created_at).where("created_at < ?", created_at).last
    if previous_message.present?
      target = previous_message
      action = "after"
    else
      target = [ room, :messages ]
      action = "prepend"
    end

    broadcast_action_to room, :messages,
                        action:,
                        target:,
                        partial: "messages/message",
                        locals: { message: self, current_room: room },
                        attributes: { maintain_scroll: true }
  end
end
