require "test_helper"

module AutomatedFeed
  class ScanRunnerTest < ActiveSupport::TestCase
    setup do
      @user1 = users(:david)
      @user2 = users(:jason)
      @parent_room = rooms(:hq)

      AutomatedFeed.config.room_scan_message_limit = 120
      AutomatedFeed.config.room_scan_thread_limit = 40
      AutomatedFeed.config.room_scan_context_backfill = 20
      AutomatedFeed.config.room_scan_lookback_hours = 12
    end

    test "determine_source_room_id returns room id for messages in a single room" do
      message1 = Message.create!(
        room: @parent_room,
        creator: @user1,
        body: ActionText::Content.new("Test message 1"),
        created_at: 1.hour.ago
      )
      message2 = Message.create!(
        room: @parent_room,
        creator: @user2,
        body: ActionText::Content.new("Test message 2"),
        created_at: 1.hour.ago
      )

      runner = ScanRunner.new(conversations: [], source: "test")
      source_room_id = runner.send(:determine_source_room_id, [message1.id, message2.id])

      assert_equal @parent_room.id, source_room_id
    end

    test "determine_source_room_id returns parent room id for messages in thread rooms" do
      parent_message = Message.create!(
        room: @parent_room,
        creator: @user1,
        body: ActionText::Content.new("Parent message"),
        created_at: 2.hours.ago
      )

      thread_room = Rooms::Thread.create!(
        name: "Thread",
        parent_message: parent_message,
        creator: @user1
      )

      thread_message = Message.create!(
        room: thread_room,
        creator: @user2,
        body: ActionText::Content.new("Thread reply"),
        created_at: 1.hour.ago
      )

      runner = ScanRunner.new(conversations: [], source: "test")
      source_room_id = runner.send(:determine_source_room_id, [thread_message.id])

      assert_equal @parent_room.id, source_room_id
    end

    test "determine_source_room_id returns parent room id for mixed parent and thread messages" do
      parent_message1 = Message.create!(
        room: @parent_room,
        creator: @user1,
        body: ActionText::Content.new("Parent message 1"),
        created_at: 2.hours.ago
      )

      parent_message2 = Message.create!(
        room: @parent_room,
        creator: @user1,
        body: ActionText::Content.new("Parent message 2"),
        created_at: 2.hours.ago
      )

      thread_room = Rooms::Thread.create!(
        name: "Thread",
        parent_message: parent_message1,
        creator: @user1
      )

      thread_message = Message.create!(
        room: thread_room,
        creator: @user2,
        body: ActionText::Content.new("Thread reply"),
        created_at: 1.hour.ago
      )

      runner = ScanRunner.new(conversations: [], source: "test")
      source_room_id = runner.send(:determine_source_room_id, [parent_message2.id, thread_message.id])

      assert_equal @parent_room.id, source_room_id
    end

    test "determine_source_room_id returns nil for empty message array" do
      runner = ScanRunner.new(conversations: [], source: "test")
      source_room_id = runner.send(:determine_source_room_id, [])

      assert_nil source_room_id
    end

    test "process_conversation passes source_room_id to deduplicator" do
      message1 = Message.create!(
        room: @parent_room,
        creator: @user1,
        body: ActionText::Content.new("Test message"),
        created_at: 1.hour.ago
      )

      conversation = {
        message_ids: [message1.id],
        title: "Test",
        summary: "Test summary",
        participants: ["@user1"],
        topic_tags: ["test"]
      }

      # Mock the deduplicator to verify it receives the source_room_id
      Deduplicator.expects(:check).with(
        conversation: conversation,
        source_room_id: @parent_room.id
      ).returns({ action: :skip, reason: "test" })

      runner = ScanRunner.new(conversations: [conversation], source: "test")
      runner.run
    end

    test "create_new_feed_card filters out already-digested messages" do
      message1 = Message.create!(
        room: @parent_room,
        creator: @user1,
        body: ActionText::Content.new("Already digested"),
        created_at: 2.hours.ago,
        in_feed: true
      )
      
      message2 = Message.create!(
        room: @parent_room,
        creator: @user2,
        body: ActionText::Content.new("New message"),
        created_at: 1.hour.ago,
        in_feed: false
      )

      conversation = {
        message_ids: [message1.id, message2.id],
        title: "Test conversation",
        summary: "Test summary",
        participants: ["@user1", "@user2"],
        topic_tags: ["test"],
        key_insight: "Test",
        preview_message_id: nil
      }

      # Mock RoomCreator to verify it only receives non-digested message IDs
      RoomCreator.expects(:create_conversation_room).with(
        has_entries(
          message_ids: [message2.id]  # Should only include message2, not message1
        )
      ).returns({ room: @parent_room, feed_card: FeedCard.new })

      # Mock deduplicator to return new_topic
      Deduplicator.stubs(:check).returns({ action: :new_topic })

      runner = ScanRunner.new(conversations: [conversation], source: "test")
      runner.run
    end

    test "create_new_feed_card skips conversation if all messages are digested" do
      message1 = Message.create!(
        room: @parent_room,
        creator: @user1,
        body: ActionText::Content.new("Already digested 1"),
        created_at: 2.hours.ago,
        in_feed: true
      )
      
      message2 = Message.create!(
        room: @parent_room,
        creator: @user2,
        body: ActionText::Content.new("Already digested 2"),
        created_at: 1.hour.ago,
        in_feed: true
      )

      conversation = {
        message_ids: [message1.id, message2.id],
        title: "Test conversation",
        summary: "Test summary",
        participants: ["@user1", "@user2"],
        topic_tags: ["test"],
        key_insight: "Test",
        preview_message_id: nil
      }

      # RoomCreator should NOT be called
      RoomCreator.expects(:create_conversation_room).never

      # Mock deduplicator to return new_topic
      Deduplicator.stubs(:check).returns({ action: :new_topic })

      runner = ScanRunner.new(conversations: [conversation], source: "test")
      runner.run
    end
  end
end
