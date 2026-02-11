namespace :weekly_digest do
  desc "Send the weekly digest email (for dev testing with letter_opener)"
  task send: :environment do
    since = ENV.fetch("SINCE", "1 week").then { |val| val.split(" ").then { |n, unit| n.to_i.public_send(unit).ago } }
    WeeklyDigestJob.new.perform(since: since)
  end
end
