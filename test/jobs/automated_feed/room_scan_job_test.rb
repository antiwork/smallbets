require "test_helper"

module AutomatedFeed
  class RoomScanJobTest < ActiveSupport::TestCase
    setup do
      AutomatedFeed.config.enable_automated_scans = true
      @room = rooms(:pets)
    end

    teardown do
      AutomatedFeed.config.enable_automated_scans = true
    end

    test "perform returns early when scans disabled" do
      AutomatedFeed.config.enable_automated_scans = false

      AutomatedFeed::Scanner.expects(:scan).never
      AutomatedFeed::ActivityTracker.expects(:mark_scanned).never

      AutomatedFeed::RoomScanJob.new.perform(@room.id)
    end

    test "perform resets tracker when room missing" do
      missing_id = -1

      AutomatedFeed::ActivityTracker.expects(:reset).with(missing_id)

      AutomatedFeed::RoomScanJob.new.perform(missing_id)
    end

    test "perform scans room and marks tracker" do
      conversation = {
        message_ids: [1, 2],
        title: "Test",
        summary: "Test summary",
        participants: [],
        topic_tags: [],
        key_insight: "Key",
        preview_message_id: 1
      }

      AutomatedFeed::Scanner.expects(:scan).with(room: @room).returns([conversation])

      runner = mock("scan_runner")
      AutomatedFeed::ScanRunner.expects(:new)
                                  .with(conversations: [conversation], source: "room", room: @room)
                                  .returns(runner)
      runner.expects(:run)

      AutomatedFeed::ActivityTracker.expects(:mark_scanned).with(@room.id)

      AutomatedFeed::RoomScanJob.new.perform(@room.id, trigger_status: :message_threshold)
    end

    test "perform resets tracker and re-raises errors" do
      AutomatedFeed::Scanner.stubs(:scan).returns([{ message_ids: [1], title: "T", summary: "S", participants: [], topic_tags: [], key_insight: "K", preview_message_id: 1 }])

      runner = mock("scan_runner")
      AutomatedFeed::ScanRunner.stubs(:new).returns(runner)
      runner.stubs(:run).raises(StandardError.new("boom"))

      AutomatedFeed::ActivityTracker.expects(:reset).with(@room.id)
      AutomatedFeed::ActivityTracker.expects(:mark_scanned).never

      assert_raises(StandardError) do
        AutomatedFeed::RoomScanJob.new.perform(@room.id)
      end
    end
  end
end
