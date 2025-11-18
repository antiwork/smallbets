module AutomatedFeed
  class RoomScanJob < ApplicationJob
    queue_as :default

    def perform(room_id, trigger_status: nil)
      return unless AutomatedFeed.config.enable_automated_scans

      room = Room.find_by(id: room_id)

      unless room
        Rails.logger.warn("[AutomatedFeed::RoomScanJob] Room #{room_id} not found")
        AutomatedFeed::ActivityTracker.reset(room_id)
        return
      end

      Rails.logger.info("[AutomatedFeed::RoomScanJob] Starting scan for room ##{room.id} (trigger: #{trigger_status || "threshold"})")

      conversations = AutomatedFeed::Scanner.scan(room: room)

      if conversations.empty?
        Rails.logger.info("[AutomatedFeed::RoomScanJob] No conversations detected for room ##{room.id}")
      else
        AutomatedFeed::ScanRunner.new(conversations:, source: "room", room: room).run
      end

      AutomatedFeed::ActivityTracker.mark_scanned(room.id)
    rescue StandardError => error
      AutomatedFeed::ActivityTracker.reset(room_id)
      Rails.logger.error("[AutomatedFeed::RoomScanJob] Error scanning room #{room_id}: #{error.class} - #{error.message}")
      Rails.logger.error(error.backtrace.join("\n"))
      Sentry.capture_exception(error, extra: { room_id: room_id }) if defined?(Sentry)
      raise
    end
  end
end
