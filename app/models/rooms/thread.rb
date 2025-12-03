# Rooms that start off from a parent message and inherit permissions from that message's room.
class Rooms::Thread < Room
  validates_presence_of :parent_message

  after_create_commit :promote_starred_users_to_visible

  def default_involvement(user: nil)
    if user.present? && (user == creator || user == parent_message&.creator)
      "everything"
    else
      "invisible"
    end
  end

  private
    def promote_starred_users_to_visible
      return unless parent_message&.room

      user_ids = parent_message.room.memberships.active.involved_in_everything.pluck(:user_id)
      scope = memberships.where(user_id: user_ids, involvement: "invisible")
      affected_user_ids = scope.pluck(:user_id)
      return if affected_user_ids.empty?

      ApplicationRecord.transaction do
        scope.update_all(involvement: "mentions", updated_at: Time.current)
      end

      # Manual broadcast since update_all bypasses callbacks
      affected_user_ids.each do |uid|
        Membership.broadcast_involvement_to(user_id: uid, room_id: id, involvement: "mentions")
      end
    end
end
