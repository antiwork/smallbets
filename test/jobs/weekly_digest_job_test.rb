require "test_helper"

class WeeklyDigestJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  setup do
    Rails.application.routes.default_url_options[:host] = "localhost:3000"
    ActionMailer::Base.default_url_options[:host] = "localhost:3000"
    ActionMailer::Base.delivery_method = :test

    @account = accounts(:signal)
    @account.update!(email_digest_enabled: true)

    @user = users(:david)
    @user.subscribe("weekly_digest")

    @source_room = rooms(:pets)

    @rooms = 10.times.map do |i|
      room = Rooms::Open.create!(name: "Topic #{i}", source_room: @source_room, creator: @user)
      FeedCard.create!(room: room, title: "Topic #{i}", summary: "Summary #{i}", type: "automated", created_at: 2.days.ago)
      Message.create!(room: room, creator: @user, body: ActionText::Content.new("Message #{i}"), created_at: 2.days.ago)
      room
    end
  end

  test "sends digest to subscribed users" do
    assert_emails 1 do
      WeeklyDigestJob.new.perform
    end
  end

  test "creates email digest entries for each topic" do
    WeeklyDigestJob.new.perform

    assert_equal 10, EmailDigestEntry.count
    assert_equal Date.current, EmailDigestEntry.first.digest_date
    assert_equal (1..10).to_a, EmailDigestEntry.order(:position).pluck(:position)
  end

  test "skips when account digest is disabled" do
    @account.update!(email_digest_enabled: false)

    assert_no_emails do
      WeeklyDigestJob.new.perform
    end

    assert_equal 0, EmailDigestEntry.count
  end

  test "skips when fewer than minimum topics" do
    FeedCard.where(room_id: @rooms.first(8).map(&:id)).destroy_all

    assert_no_emails do
      WeeklyDigestJob.new.perform
    end

    assert_equal 0, EmailDigestEntry.count
  end

  test "does not send to unsubscribed users" do
    @user.unsubscribe("weekly_digest")

    assert_no_emails do
      WeeklyDigestJob.new.perform
    end
  end

  test "excludes rooms already sent in previous digests" do
    EmailDigestEntry.create!(room: @rooms.first, digest_date: 1.week.ago, position: 1)

    WeeklyDigestJob.new.perform

    room_ids = EmailDigestEntry.where(digest_date: Date.current).pluck(:room_id)
    assert_not_includes room_ids, @rooms.first.id
  end

  test "excludes rooms marked as exclude_from_digest" do
    @rooms.first.update!(exclude_from_digest: true)

    WeeklyDigestJob.new.perform

    room_ids = EmailDigestEntry.where(digest_date: Date.current).pluck(:room_id)
    assert_not_includes room_ids, @rooms.first.id
  end

  test "does not include topics older than one week" do
    FeedCard.update_all(created_at: 2.weeks.ago)

    assert_no_emails do
      WeeklyDigestJob.new.perform
    end
  end
end
