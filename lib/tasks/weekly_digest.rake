namespace :weekly_digest do
  desc "Send the weekly digest email (for dev testing with letter_opener)"
  task send: :environment do
    WeeklyDigestJob.new.perform
  end
end
