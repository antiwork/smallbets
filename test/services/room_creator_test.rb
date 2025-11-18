require "test_helper"

class RoomCreatorTest < ActiveSupport::TestCase
  setup do
    @user1 = users(:david)
    @user2 = users(:jason)
    @source_room = rooms(:pets)
  end

  test "creates conversation room with only specified message IDs" do
    # Create parent message in source room
    parent_message = Message.create!(
      room: @source_room,
      creator: @user1,
      body: ActionText::Content.new("Parent message"),
      created_at: 2.hours.ago
    )

    # Create thread room
    thread_room = Rooms::Thread.create!(
      parent_message: parent_message,
      creator: @user1
    )
    thread_room.memberships.grant_to(User.active)

    # Create multiple messages in thread
    thread_msg1 = Message.create!(
      room: thread_room,
      creator: @user1,
      body: ActionText::Content.new("Thread reply 1"),
      created_at: 1.hour.ago
    )
    thread_msg2 = Message.create!(
      room: thread_room,
      creator: @user2,
      body: ActionText::Content.new("Thread reply 2"),
      created_at: 50.minutes.ago
    )
    thread_msg3 = Message.create!(
      room: thread_room,
      creator: @user1,
      body: ActionText::Content.new("Thread reply 3"),
      created_at: 40.minutes.ago
    )

    # Create conversation room with only thread_msg1 and thread_msg3 (not thread_msg2)
    result = RoomCreator.create_conversation_room(
      message_ids: [thread_msg1.id, thread_msg3.id],
      title: "Test Conversation",
      summary: "Test summary",
      type: "automated",
      promoted_by: nil
    )

    conversation_room = result[:room]
    copied_messages = conversation_room.messages.order(:created_at)

    # Should only have 2 messages (the ones we specified)
    assert_equal 2, copied_messages.count
    assert_equal [thread_msg1.id, thread_msg3.id], copied_messages.map { |m| m.original_message_id }
    assert_equal @source_room, conversation_room.source_room
  end

  test "creates conversation room with mix of top-level and thread messages" do
    # Create top-level messages
    top_msg1 = Message.create!(
      room: @source_room,
      creator: @user1,
      body: ActionText::Content.new("Top message 1"),
      created_at: 2.hours.ago
    )
    top_msg2 = Message.create!(
      room: @source_room,
      creator: @user2,
      body: ActionText::Content.new("Top message 2"),
      created_at: 1.hour.ago
    )

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
      created_at: 50.minutes.ago
    )

    # Create another thread message that should NOT be included
    Message.create!(
      room: thread_room,
      creator: @user2,
      body: ActionText::Content.new("Thread reply not included"),
      created_at: 40.minutes.ago
    )

    # Create conversation room with top_msg1, top_msg2, and thread_msg (but not the other thread reply)
    result = RoomCreator.create_conversation_room(
      message_ids: [top_msg1.id, top_msg2.id, thread_msg.id],
      title: "Mixed Conversation",
      summary: "Mixed summary",
      type: "automated",
      promoted_by: nil
    )

    conversation_room = result[:room]
    copied_messages = conversation_room.messages.order(:created_at)

    # Should only have 3 messages (the ones we specified)
    assert_equal 3, copied_messages.count
    assert_equal [top_msg1.id, top_msg2.id, thread_msg.id], copied_messages.map { |m| m.original_message_id }
    assert_equal @source_room, conversation_room.source_room
  end

  test "fingerprint matches only specified message IDs" do
    msg1 = Message.create!(
      room: @source_room,
      creator: @user1,
      body: ActionText::Content.new("Message 1"),
      created_at: 1.hour.ago
    )
    msg2 = Message.create!(
      room: @source_room,
      creator: @user2,
      body: ActionText::Content.new("Message 2"),
      created_at: 50.minutes.ago
    )
    msg3 = Message.create!(
      room: @source_room,
      creator: @user1,
      body: ActionText::Content.new("Message 3"),
      created_at: 40.minutes.ago
    )

    # Create first conversation room with msg1 and msg2
    result1 = RoomCreator.create_conversation_room(
      message_ids: [msg1.id, msg2.id],
      title: "First Conversation",
      summary: "First summary",
      type: "automated",
      promoted_by: nil
    )

    feed_card1 = result1[:feed_card]
    expected_fingerprint1 = Digest::SHA256.hexdigest([msg1.id, msg2.id].sort.join(","))
    assert_equal expected_fingerprint1, feed_card1.message_fingerprint

    # Try to create second conversation room with same messages - should find existing
    result2 = RoomCreator.create_conversation_room(
      message_ids: [msg1.id, msg2.id],
      title: "Duplicate Conversation",
      summary: "Duplicate summary",
      type: "automated",
      promoted_by: nil
    )

    # Should return the same room
    assert_equal result1[:room].id, result2[:room].id
    assert_equal feed_card1.id, result2[:feed_card].id

    # Create third conversation room with msg1, msg2, and msg3 - should be new
    result3 = RoomCreator.create_conversation_room(
      message_ids: [msg1.id, msg2.id, msg3.id],
      title: "Extended Conversation",
      summary: "Extended summary",
      type: "automated",
      promoted_by: nil
    )

    # Should be a different room
    assert_not_equal result1[:room].id, result3[:room].id
    assert_equal 3, result3[:room].messages.count
  end

  test "rejects messages from multiple non-thread rooms" do
    # Create messages in two different rooms
    room_a = @source_room
    room_b = rooms(:designers)

    msg_a = Message.create!(
      room: room_a,
      creator: @user1,
      body: ActionText::Content.new("Message in room A"),
      created_at: 1.hour.ago
    )

    msg_b = Message.create!(
      room: room_b,
      creator: @user2,
      body: ActionText::Content.new("Message in room B"),
      created_at: 50.minutes.ago
    )

    # Attempt to create conversation with messages from different rooms
    error = assert_raises(RoomCreator::InvalidStateError) do
      RoomCreator.create_conversation_room(
        message_ids: [msg_a.id, msg_b.id],
        title: "Cross-room conversation",
        summary: "Should fail",
        type: "automated",
        promoted_by: nil
      )
    end

    assert_match(/Messages must be from the same room or related threads/, error.message)
  end

  test "rejects messages from threads with different parent rooms" do
    # Create messages in two different rooms with their own threads
    room_a = @source_room
    room_b = rooms(:designers)

    msg_a = Message.create!(
      room: room_a,
      creator: @user1,
      body: ActionText::Content.new("Message in room A"),
      created_at: 2.hours.ago
    )

    msg_b = Message.create!(
      room: room_b,
      creator: @user2,
      body: ActionText::Content.new("Message in room B"),
      created_at: 2.hours.ago
    )

    # Create thread from room A
    thread_a = Rooms::Thread.create!(
      parent_message: msg_a,
      creator: @user1
    )
    thread_a.memberships.grant_to(User.active)

    thread_msg_a = Message.create!(
      room: thread_a,
      creator: @user1,
      body: ActionText::Content.new("Thread in room A"),
      created_at: 1.hour.ago
    )

    # Create thread from room B
    thread_b = Rooms::Thread.create!(
      parent_message: msg_b,
      creator: @user2
    )
    thread_b.memberships.grant_to(User.active)

    thread_msg_b = Message.create!(
      room: thread_b,
      creator: @user2,
      body: ActionText::Content.new("Thread in room B"),
      created_at: 1.hour.ago
    )

    # Attempt to create conversation with messages from threads with different parents
    error = assert_raises(RoomCreator::InvalidStateError) do
      RoomCreator.create_conversation_room(
        message_ids: [thread_msg_a.id, thread_msg_b.id],
        title: "Cross-thread conversation",
        summary: "Should fail",
        type: "automated",
        promoted_by: nil
      )
    end

    assert_match(/Messages from threads with different parent rooms cannot be combined/, error.message)
  end

  test "rejects messages from non-thread room that doesn't match thread parent room" do
    # Create Room A with a thread
    room_a = @source_room
    room_b = rooms(:designers)

    msg_a = Message.create!(
      room: room_a,
      creator: @user1,
      body: ActionText::Content.new("Message in room A"),
      created_at: 2.hours.ago
    )

    # Create thread from room A
    thread_a = Rooms::Thread.create!(
      parent_message: msg_a,
      creator: @user1
    )
    thread_a.memberships.grant_to(User.active)

    thread_msg_a = Message.create!(
      room: thread_a,
      creator: @user1,
      body: ActionText::Content.new("Thread in room A"),
      created_at: 1.hour.ago
    )

    # Create message in Room B
    msg_b = Message.create!(
      room: room_b,
      creator: @user2,
      body: ActionText::Content.new("Message in room B"),
      created_at: 1.hour.ago
    )

    # Attempt to create conversation with thread from room A and message from room B
    error = assert_raises(RoomCreator::InvalidStateError) do
      RoomCreator.create_conversation_room(
        message_ids: [thread_msg_a.id, msg_b.id],
        title: "Mixed room conversation",
        summary: "Should fail",
        type: "automated",
        promoted_by: nil
      )
    end

    assert_match(/Messages from non-thread room .* that doesn't match parent room .* cannot be combined/, error.message)
  end
end
