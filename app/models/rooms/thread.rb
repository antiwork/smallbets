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
end
