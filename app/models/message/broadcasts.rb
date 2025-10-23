module Message::Broadcasts
  def broadcast_create
    broadcast_append_to room, :messages, target: [ room, :messages ], partial: "messages/message", locals: { current_room: room }
    ActionCable.server.broadcast("unread_rooms", { roomId: room.id, roomSize: room.messages_count, roomUpdatedAt: created_at.iso8601 })

    broadcast_notifications
    broadcast_to_inbox_mentions
    broadcast_to_inbox_threads
  end

  def broadcast_update
    broadcast_notifications(ignore_if_older_message: true)
  end

  def broadcast_notifications(ignore_if_older_message: false)
    memberships = if mentions_everyone?
      room.memberships
    else
      room.memberships.where(user_id: mentionee_ids)
    end

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

  def broadcast_to_inbox_mentions
    return if mentionee_ids.blank?
    return if mentions_everyone?

    mentionees.each do |user|
      next if user.id == creator_id

      broadcast_remove_to user, :inbox_mentions,
                         target: ActionView::RecordIdentifier.dom_id(self)

      broadcast_append_to user, :inbox_mentions,
                          target: "inbox",
                          partial: "messages/message",
                          locals: {
                            message: self,
                            current_room: nil,
                            first_unread_message: nil,
                            timestamp_style: :long_datetime,
                            show_date_separator: true
                          }
    end
  end

  def broadcast_to_inbox_threads

    return unless room.thread? && room.parent_message
    
    parent_message = room.parent_message
    thread = room
    
    thread.reload
    
    thread_user_ids = thread.memberships.active.visible.pluck(:user_id)
    parent_room_user_ids = parent_message.room.memberships.active.involved_in_everything.pluck(:user_id)
    all_user_ids = (thread_user_ids + parent_room_user_ids).uniq
    
    all_user_ids.each do |user_id|
      next if user_id == creator_id
      user = User.find(user_id)
      
      if thread.messages_count == 1
        broadcast_append_to user, :inbox_threads,
                           target: "inbox",
                           partial: "messages/message",
                           locals: {
                             message: parent_message,
                             timestamp_style: :long_datetime,
                             show_date_separator: true
                           }
      else
        broadcast_replace_to user, :inbox_threads,
                            target: ActionView::RecordIdentifier.dom_id(parent_message, :threads),
                            partial: "messages/threads",
                            locals: { message: parent_message.reload }
      end
    end
  end
end
