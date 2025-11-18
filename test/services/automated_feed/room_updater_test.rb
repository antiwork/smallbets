require "test_helper"

module AutomatedFeed
  class RoomUpdaterTest < ActiveSupport::TestCase
    setup do
      @user1 = users(:david)
      @user2 = users(:jason)
      @source_room = rooms(:pets)
    end

    test "update_continuation only copies specified message IDs" do
      # Create initial messages
      msg1 = Message.create!(
        room: @source_room,
        creator: @user1,
        body: ActionText::Content.new("Initial message 1"),
        created_at: 3.hours.ago
      )
      msg2 = Message.create!(
        room: @source_room,
        creator: @user2,
        body: ActionText::Content.new("Initial message 2"),
        created_at: 2.hours.ago
      )

      # Create conversation room with initial messages
      result = RoomCreator.create_conversation_room(
        message_ids: [msg1.id, msg2.id],
        title: "Initial Conversation",
        summary: "Initial summary",
        type: "automated",
        promoted_by: nil
      )

      feed_card = result[:feed_card]
      conversation_room = result[:room]

      # Create thread
      thread_room = Rooms::Thread.create!(
        parent_message: msg1,
        creator: @user1
      )
      thread_room.memberships.grant_to(User.active)

      # Create new thread messages
      thread_msg1 = Message.create!(
        room: thread_room,
        creator: @user1,
        body: ActionText::Content.new("Thread continuation 1"),
        created_at: 1.hour.ago
      )
      thread_msg2 = Message.create!(
        room: thread_room,
        creator: @user2,
        body: ActionText::Content.new("Thread continuation 2"),
        created_at: 50.minutes.ago
      )
      thread_msg3 = Message.create!(
        room: thread_room,
        creator: @user1,
        body: ActionText::Content.new("Thread continuation 3"),
        created_at: 40.minutes.ago
      )

      # Update continuation with only thread_msg1 and thread_msg3 (not thread_msg2)
      RoomUpdater.update_continuation(
        feed_card: feed_card,
        new_message_ids: [thread_msg1.id, thread_msg3.id],
        updated_summary: "Updated summary"
      )

      conversation_room.reload
      copied_messages = conversation_room.messages.order(:created_at)

      # Should have original 2 messages + 2 new messages = 4 total
      assert_equal 4, copied_messages.count
      original_message_ids = copied_messages.map { |m| m.original_message_id }
      assert_includes original_message_ids, msg1.id
      assert_includes original_message_ids, msg2.id
      assert_includes original_message_ids, thread_msg1.id
      assert_includes original_message_ids, thread_msg3.id
      assert_not_includes original_message_ids, thread_msg2.id

      # Verify updated summary
      feed_card.reload
      assert_equal "Updated summary", feed_card.summary
    end

    test "update_continuation skips already copied messages" do
      msg1 = Message.create!(
        room: @source_room,
        creator: @user1,
        body: ActionText::Content.new("Message 1"),
        created_at: 2.hours.ago
      )
      msg2 = Message.create!(
        room: @source_room,
        creator: @user2,
        body: ActionText::Content.new("Message 2"),
        created_at: 1.hour.ago
      )

      # Create conversation room
      result = RoomCreator.create_conversation_room(
        message_ids: [msg1.id, msg2.id],
        title: "Test Conversation",
        summary: "Test summary",
        type: "automated",
        promoted_by: nil
      )

      feed_card = result[:feed_card]
      conversation_room = result[:room]

      # Try to update with msg1 (already copied) and a new msg3
      msg3 = Message.create!(
        room: @source_room,
        creator: @user1,
        body: ActionText::Content.new("Message 3"),
        created_at: 30.minutes.ago
      )

      RoomUpdater.update_continuation(
        feed_card: feed_card,
        new_message_ids: [msg1.id, msg3.id],
        updated_summary: nil
      )

      conversation_room.reload
      copied_messages = conversation_room.messages.order(:created_at)

      # Should still have 3 messages (msg1, msg2, msg3) - msg1 should not be duplicated
      assert_equal 3, copied_messages.count
      original_message_ids = copied_messages.map { |m| m.original_message_id }
      assert_equal [msg1.id, msg2.id, msg3.id], original_message_ids.sort
    end

    test "update_continuation handles mixed top-level and thread messages" do
      top_msg1 = Message.create!(
        room: @source_room,
        creator: @user1,
        body: ActionText::Content.new("Top message"),
        created_at: 2.hours.ago
      )

      # Create initial conversation room
      result = RoomCreator.create_conversation_room(
        message_ids: [top_msg1.id],
        title: "Test Conversation",
        summary: "Test summary",
        type: "automated",
        promoted_by: nil
      )

      feed_card = result[:feed_card]

      # Create thread
      thread_room = Rooms::Thread.create!(
        parent_message: top_msg1,
        creator: @user1
      )
      thread_room.memberships.grant_to(User.active)

      thread_msg = Message.create!(
        room: thread_room,
        creator: @user1,
        body: ActionText::Content.new("Thread reply"),
        created_at: 1.hour.ago
      )

      # Create a new top-level message
      top_msg2 = Message.create!(
        room: @source_room,
        creator: @user2,
        body: ActionText::Content.new("New top message"),
        created_at: 30.minutes.ago
      )

      # Update with both thread reply and new top-level message
      RoomUpdater.update_continuation(
        feed_card: feed_card,
        new_message_ids: [thread_msg.id, top_msg2.id]
      )

      feed_card.room.reload
      copied_messages = feed_card.room.messages.order(:created_at)

      # Should have 3 messages total
      assert_equal 3, copied_messages.count
      original_message_ids = copied_messages.map { |m| m.original_message_id }
      assert_equal [top_msg1.id, thread_msg.id, top_msg2.id], original_message_ids.sort
    end
  end
end
