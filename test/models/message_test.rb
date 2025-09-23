require "test_helper"

class MessageTest < ActiveSupport::TestCase
  include ActionCable::TestHelper, ActiveJob::TestHelper

  test "creating a message enqueues to push later" do
    assert_enqueued_jobs 1, only: [ Room::PushMessageJob ] do
      create_new_message_in rooms(:designers)
    end
  end

  test "all emoji" do
    assert Message.new(body: "😄🤘").plain_text_body.all_emoji?
    assert_not Message.new(body: "Haha! 😄🤘").plain_text_body.all_emoji?
    assert_not Message.new(body: "🔥\nmultiple lines\n💯").plain_text_body.all_emoji?
    assert_not Message.new(body: "🔥 💯").plain_text_body.all_emoji?
  end

  test "mentionees" do
    message = Message.new room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:david)}</div>", creator: users(:jason), client_message_id: "earth"
    assert_equal [ users(:david) ], message.mentionees

    message_with_duplicate_mentions = Message.new room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:david)} #{mention_attachment_for(:david)}</div>", creator: users(:jason), client_message_id: "earth"
    assert_equal [ users(:david) ], message.mentionees

    message_mentioning_a_non_member = Message.new room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:kevin)}</div>", creator: users(:jason), client_message_id: "earth"
    assert_equal [], message_mentioning_a_non_member.mentionees
  end

  test "deactivating message clears unread timestamps pointing to it" do
    room = rooms(:pets)
    user = users(:david)
    membership = room.memberships.find_by(user: user)
    
    # Create two messages
    message1 = room.messages.create!(creator: users(:jason), body: "First message", client_message_id: "msg1")
    message2 = room.messages.create!(creator: users(:jason), body: "Second message", client_message_id: "msg2")
    
    # Mark membership as unread at message1
    membership.update!(unread_at: message1.created_at)
    assert membership.unread?
    assert_equal message1.created_at, membership.unread_at
    
    # Deactivate message1
    message1.deactivate
    
    # Should update unread_at to message2 since it's the next unread message
    membership.reload
    assert membership.unread?
    assert_equal message2.created_at, membership.unread_at
  end

  test "deactivating last unread message marks membership as read" do
    room = rooms(:pets)
    user = users(:david)
    membership = room.memberships.find_by(user: user)
    
    # Create one message
    message = room.messages.create!(creator: users(:jason), body: "Only message", client_message_id: "msg1")
    
    # Mark membership as unread at this message
    membership.update!(unread_at: message.created_at)
    assert membership.unread?
    
    # Deactivate the message
    message.deactivate
    
    # Should mark membership as read since no unread messages remain
    membership.reload
    assert membership.read?
    assert_nil membership.unread_at
  end

  test "deactivating message only affects memberships with matching unread_at" do
    room = rooms(:pets)
    user1 = users(:david)
    user2 = users(:jason)
    membership1 = room.memberships.find_by(user: user1)
    membership2 = room.memberships.find_by(user: user2)
    
    # Create two messages
    message1 = room.messages.create!(creator: users(:jason), body: "First message", client_message_id: "msg1")
    message2 = room.messages.create!(creator: users(:jason), body: "Second message", client_message_id: "msg2")
    
    # Mark memberships with different unread_at timestamps
    membership1.update!(unread_at: message1.created_at)
    membership2.update!(unread_at: message2.created_at)
    
    # Deactivate message1
    message1.deactivate
    
    # Only membership1 should be affected
    membership1.reload
    membership2.reload
    
    assert_equal message2.created_at, membership1.unread_at  # Updated to next message
    assert_equal message2.created_at, membership2.unread_at  # Unchanged
  end

  private
    def create_new_message_in(room)
      room.messages.create!(creator: users(:jason), body: "Hello", client_message_id: "123")
    end
end
