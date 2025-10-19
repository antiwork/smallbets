class RoomUpdateBroadcastJob < ApplicationJob
  queue_as :default

  rescue_from ActiveJob::DeserializationError do
  end

  def perform(room)
    # Throttle updates to once every 5 seconds per room to avoid a thundering herd problem.
    lock_key = "room_update_broadcast_job_lock:#{room.id}"
    return unless Kredis.redis.set(lock_key, "1", nx: true, ex: 5)

    room.memberships.visible.find_each do |membership|
      RoomMembershipBroadcastJob.perform_later(membership)
    end
  end
end
