module WelcomeHelper
  def welcome_checklist_complete?
    has_avatar? && has_posted_message? && has_starred_room?
  end
  
  def has_avatar?
    Current.user.avatar.attached?
  end
  
  def has_posted_message?
    Message.active
      .joins(:room)
      .where(creator_id: Current.user.id)
      .where(rooms: { type: "Rooms::Open" })
      .exists?
  end
  
  def has_starred_room?
    Membership.active
      .where(user_id: Current.user.id)
      .where(involvement: "everything")
      .exists?
  end
end
