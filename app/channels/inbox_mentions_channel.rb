class InboxMentionsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user, :inbox_mentions
  end
end

