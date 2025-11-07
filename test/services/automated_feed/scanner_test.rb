require "test_helper"

module AutomatedFeed
  class ScannerTest < ActiveSupport::TestCase
    setup do
      @user1 = users(:david)
      @user2 = users(:jason)
      @room = rooms(:hq)
      
      AutomatedFeed.config.enable_automated_scans = true
      AutomatedFeed.config.room_scan_message_limit = 25
      AutomatedFeed.config.room_scan_thread_limit = 10
      AutomatedFeed.config.room_scan_context_backfill = 5
      AutomatedFeed.config.room_scan_lookback_hours = 24
      AutomatedFeed.config.max_conversations_per_scan = 999
      
      AutomatedFeed::Scanner # ensure autoload (and loads AIGateway via require_relative)
      @ai_gateway = Object.const_get("AIGateway")

      @ai_gateway.stubs(:complete).returns({
        "conversations" => [
          {
            "message_ids" => [1, 2, 3],
            "title" => "Test conversation title",
            "summary" => "Test summary",
            "participants" => ["@user1", "@user2"],
            "topic_tags" => ["test-tag"]
          }
        ]
      }.to_json)
    end

    teardown do
      AutomatedFeed.config.enable_automated_scans = true
      AutomatedFeed.config.room_scan_message_limit = 120
      AutomatedFeed.config.room_scan_thread_limit = 40
      AutomatedFeed.config.room_scan_context_backfill = 20
      AutomatedFeed.config.room_scan_lookback_hours = 12
      AutomatedFeed.config.max_conversations_per_scan = 999
    end

    test "scan returns empty array when disabled" do
      AutomatedFeed.config.enable_automated_scans = false
      
      result = Scanner.scan
      
      assert_equal [], result
    end

    test "scan returns empty array when no messages" do
      Message.stubs(:active).returns(Message.none)
      
      result = Scanner.scan
      
      assert_equal [], result
    end

    test "scan detects conversations and formats correctly" do
      @ai_gateway.unstub(:complete)
      message1 = Message.create!(
        room: @room,
        creator: @user1,
        body: ActionText::Content.new("Test message 1"),
        created_at: 1.hour.ago
      )
      message2 = Message.create!(
        room: @room,
        creator: @user2,
        body: ActionText::Content.new("Test message 2"),
        created_at: 1.hour.ago
      )

      @ai_gateway.expects(:complete).with(
        has_entries(
          prompt: includes("RECENT MESSAGES"),
          model: "anthropic/claude-haiku-4.5"
        )
      ).returns({
        "conversations" => [
          {
            "message_ids" => [message1.id, message2.id],
            "title" => "Test conversation",
            "summary" => "Test summary",
            "participants" => ["@user1", "@user2"],
            "topic_tags" => ["test"]
          }
        ]
      }.to_json)

      result = Scanner.scan

      assert_equal 1, result.count
      assert_equal [message1.id, message2.id], result.first[:message_ids]
      assert_equal "Test conversation", result.first[:title]
    end

    test "room scan includes digested messages outside lookback for context" do
      @ai_gateway.unstub(:complete)
      old_message = Message.create!(
        room: @room,
        creator: @user1,
        body: ActionText::Content.new("Old context message"),
        created_at: 3.hours.ago,
        in_feed: true
      )

      new_message = Message.create!(
        room: @room,
        creator: @user2,
        body: ActionText::Content.new("Fresh message"),
        created_at: 5.minutes.ago,
        in_feed: false
      )

      @ai_gateway.expects(:complete).with(
        has_entries(
          prompt: includes("Old context message")
        )
      ).returns({ "conversations" => [] }.to_json)

      Scanner.scan(room: @room)
    end

    test "scan handles AI errors gracefully" do
      message = Message.create!(
        room: @room,
        creator: @user1,
        body: ActionText::Content.new("Trigger AI error"),
        created_at: 10.minutes.ago
      )
      
      @ai_gateway.unstub(:complete)
      @ai_gateway.expects(:complete).raises(@ai_gateway::Error.new("API error"))
      
      result = Scanner.scan
      
      assert_equal [], result
    end

    test "scan excludes conversation rooms" do
      conversation_room = Room.create!(
        name: "Conversation Room",
        type: "Rooms::Open",
        source_room: @room,
        creator: @user1
      )
      
      message = Message.create!(
        room: conversation_room,
        creator: @user1,
        body: ActionText::Content.new("Test"),
        created_at: 1.hour.ago
      )

      result = Scanner.scan

      assert_equal [], result
    end

    test "scan excludes already digested messages" do
      message = Message.create!(
        room: @room,
        creator: @user1,
        body: ActionText::Content.new("Test"),
        created_at: 1.hour.ago,
        in_feed: true
      )

      result = Scanner.scan

      assert_equal [], result
    end

    test "scan respects max conversations per scan" do
      AutomatedFeed.config.max_conversations_per_scan = 1

      message1 = Message.create!(
        room: @room,
        creator: @user1,
        body: ActionText::Content.new("First message"),
        created_at: 30.minutes.ago
      )

      message2 = Message.create!(
        room: @room,
        creator: @user2,
        body: ActionText::Content.new("Second message"),
        created_at: 25.minutes.ago
      )

      message3 = Message.create!(
        room: @room,
        creator: @user1,
        body: ActionText::Content.new("Third message"),
        created_at: 20.minutes.ago
      )

      message4 = Message.create!(
        room: @room,
        creator: @user2,
        body: ActionText::Content.new("Fourth message"),
        created_at: 15.minutes.ago
      )

      @ai_gateway.unstub(:complete)
      @ai_gateway.expects(:complete).returns({
        "conversations" => [
          {
            "message_ids" => [message1.id, message2.id],
            "title" => "Conversation 1",
            "summary" => "Summary 1",
            "participants" => ["@user1", "@user2"],
            "topic_tags" => ["tag-1"],
            "key_insight" => "Insight 1",
            "preview_message_id" => nil
          },
          {
            "message_ids" => [message3.id, message4.id],
            "title" => "Conversation 2",
            "summary" => "Summary 2",
            "participants" => ["@user1", "@user2"],
            "topic_tags" => ["tag-2"],
            "key_insight" => "Insight 2",
            "preview_message_id" => nil
          }
        ]
      }.to_json)

      result = Scanner.scan

      assert_equal 1, result.size
      assert_equal [message1.id, message2.id], result.first[:message_ids]
    end
  end
end
