# Rooms that start off from a parent message and inherit permissions from that message's room.
class Rooms::Thread < Room
  validates_presence_of :parent_message

  def default_involvement(user: nil)
    if user.present? && (user == creator || user == parent_message&.creator)
      "everything"
    else
      "invisible"
    end
  end

  # Check if a user is participating in this thread
  # A user participates if they:
  # - Created the parent message (the original message being threaded)
  # - Created the thread (first commenter)
  # - Have a visible membership (not "invisible" involvement)
  # - Were mentioned in the thread (which gives them "mentions" involvement)
  def participating?(user)
    return false unless user

    user_id = user.id

    # Parent message creator is always a participant
    return true if parent_message&.creator_id == user_id

    # Thread creator is always a participant
    return true if creator_id == user_id

    # Check if user has a visible membership (not "invisible")
    membership = memberships.active.find_by(user_id: user_id)
    return false unless membership

    # User is participating if they have a visible involvement (not "invisible")
    membership.involved_in_invisible? ? false : true
  end

  # Check if a participating user has unread messages in this thread
  def unread_for_participating?(user)
    return false unless user

    membership = memberships.active.find_by(user_id: user.id)
    return false unless membership

    membership.unread?
  end
end
