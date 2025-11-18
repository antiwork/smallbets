require "test_helper"

module AutomatedFeed
  class ScheduledScanJobTest < ActiveSupport::TestCase
    setup do
      AutomatedFeed.config.enable_automated_scans = true
    end

    teardown do
      AutomatedFeed.config.enable_automated_scans = true
    end

    test "perform returns early when disabled" do
      AutomatedFeed.config.enable_automated_scans = false

      AutomatedFeed::Scanner.expects(:scan).never
      AutomatedFeed::ActivityTracker.expects(:active_room_ids).never

      AutomatedFeed::ScheduledScanJob.new.perform
    end

    test "perform runs scan runner for conversations" do
      conversation = {
        message_ids: [1, 2],
        title: "Test",
        summary: "Test summary",
        participants: [],
        topic_tags: [],
        key_insight: "Key",
        preview_message_id: 1
      }

      AutomatedFeed::Scanner.stubs(:scan).returns([conversation])

      runner = mock("scan_runner")
      AutomatedFeed::ScanRunner.expects(:new)
                                  .with(conversations: [conversation], source: "scheduled")
                                  .returns(runner)
      runner.expects(:run)

      AutomatedFeed::ActivityTracker.expects(:active_room_ids).returns(["1"])
      AutomatedFeed::ActivityTracker.expects(:mark_scanned).with("1")

      AutomatedFeed::ScheduledScanJob.new.perform
    end

    test "perform resets activity tracker when no conversations" do
      AutomatedFeed::Scanner.stubs(:scan).returns([])

      AutomatedFeed::ScanRunner.expects(:new).never

      AutomatedFeed::ActivityTracker.expects(:active_room_ids).returns(["2", "3"])
      AutomatedFeed::ActivityTracker.expects(:mark_scanned).with("2")
      AutomatedFeed::ActivityTracker.expects(:mark_scanned).with("3")

      AutomatedFeed::ScheduledScanJob.new.perform
    end

    test "perform still resets tracker when scan raises" do
      AutomatedFeed::Scanner.stubs(:scan).raises(StandardError.new("boom"))

      AutomatedFeed::ActivityTracker.expects(:active_room_ids).returns(["4"])
      AutomatedFeed::ActivityTracker.expects(:mark_scanned).with("4")

      assert_raises(StandardError) do
        AutomatedFeed::ScheduledScanJob.new.perform
      end
    end
  end
end
