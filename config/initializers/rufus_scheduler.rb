require "rufus-scheduler"

Rails.application.config.after_initialize do
  if Rails.env.production? && defined?(Rails::Server) && !defined?($rufus_scheduler)
    Rails.logger.info "Starting Rufus scheduler."
    $rufus_scheduler = Rufus::Scheduler.new

    $rufus_scheduler.cron "0 9,18 * * * America/Los_Angeles" do
      UnreadMentionsNotifierJob.new.perform
    end

    fallback_cron = ENV.fetch("AUTOMATED_FEED_FALLBACK_CRON", "0 */2 * * *")
    Rails.logger.info "Scheduling AutomatedFeed fallback scans with cron: #{fallback_cron}"

    $rufus_scheduler.cron fallback_cron do
      AutomatedFeed::ScheduledScanJob.perform_later
    end
  end
end
