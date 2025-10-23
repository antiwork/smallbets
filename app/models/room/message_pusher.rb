class Room::MessagePusher
  attr_reader :room, :message

  def initialize(room:, message:)
    @room, @message = room, message
  end

  def push
    if room.direct?
      push_to_everyone_in_room(build_direct_payload)
    else
      push_to_mentionees(build_shared_payload)
    end
  end

  private
    def build_direct_payload
      {
        title: message.creator.name,
        body: message.plain_text_body,
        path: Rails.application.routes.url_helpers.room_path(room)
      }
    end

    def build_shared_payload
      {
        title: room.display_name,
        body: "#{message.creator.name}: #{message.plain_text_body}",
        path: Rails.application.routes.url_helpers.room_path(room)
      }
    end

    def push_to_everyone_in_room(payload)
      enqueue_payload_for_delivery payload, relevant_subscriptions
    end

    def push_to_mentionees(payload)
      enqueue_payload_for_delivery payload, push_subscriptions_for_mentionable_users(message.mentionee_ids)
    end

    def push_subscriptions_for_mentionable_users(mentionee_ids)
      relevant_subscriptions.where(user_id: mentionee_ids)
    end

    def relevant_subscriptions
      Push::Subscription
        .joins(user: :memberships)
        .merge(Membership.disconnected.where(room: room).where.not(user: message.creator))
    end

    def enqueue_payload_for_delivery(payload, subscriptions)
      Rails.configuration.x.web_push_pool.queue(payload, subscriptions)
    end
end
