module AutomatedFeed
  class ScheduledScanJob < ApplicationJob
    queue_as :default

    def perform
      return unless AutomatedFeed.config.enable_automated_scans

      Rails.logger.info("[AutomatedFeed::ScheduledScanJob] Starting scheduled scan")

      conversations = AutomatedFeed::Scanner.scan

      if conversations.empty?
        Rails.logger.info("[AutomatedFeed::ScheduledScanJob] No conversations detected in scheduled scan")
      else
        Rails.logger.info("[AutomatedFeed::ScheduledScanJob] Processing #{conversations.count} conversations")
        AutomatedFeed::ScanRunner.new(conversations:, source: "scheduled").run
      end
    ensure
      reset_activity_tracker if AutomatedFeed.config.enable_automated_scans
      Rails.logger.info("[AutomatedFeed::ScheduledScanJob] Scan complete")
    end

    private

    def reset_activity_tracker
      room_ids = AutomatedFeed::ActivityTracker.active_room_ids
      return if room_ids.empty?

      room_ids.each do |room_id|
        AutomatedFeed::ActivityTracker.mark_scanned(room_id)
      end
    end
  end
end
