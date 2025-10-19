class InboxThreadsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user, :inbox_threads
  end
end

