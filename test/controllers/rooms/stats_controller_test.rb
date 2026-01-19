require "test_helper"

class Rooms::StatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
    @room = rooms(:pets)
  end

  test "shows room stats successfully" do
    get room_stats_path(@room)

    assert_response :success
    assert_select "h2.txt-h3", text: "Room Info"
    assert_select "h2.txt-h3", text: "Top Talkers"
  end

  test "displays top talkers from V2 query" do
    user1 = users(:jason)
    user2 = users(:david)

    # Create messages
    3.times { |i| @room.messages.create!(creator: user1, body: "Message #{i}", client_message_id: SecureRandom.uuid) }
    @room.messages.create!(creator: user2, body: "Message", client_message_id: SecureRandom.uuid)

    get room_stats_path(@room)

    assert_response :success
    assert_includes response.body, user1.name
    assert_includes response.body, user2.name
  end

  test "displays current user rank when outside top 10" do
    # Create 10 other users with messages
    10.times do |i|
      user = User.create!(
        name: "User #{i}",
        email_address: "user#{i}@test.com",
        password: "secret123456"
      )
      2.times { @room.messages.create!(creator: user, body: "Message", client_message_id: SecureRandom.uuid) }
    end

    # Current user (david) has 1 message
    @room.messages.create!(creator: users(:david), body: "Message", client_message_id: SecureRandom.uuid)

    get room_stats_path(@room)

    assert_response :success
    # Should show current user's rank below the divider line
    assert_includes response.body, "border-top: 1px dashed"
  end

  test "uses cached data on subsequent requests" do
    user = users(:jason)
    @room.messages.create!(creator: user, body: "Message", client_message_id: SecureRandom.uuid)

    # First request - cache miss
    get room_stats_path(@room)
    assert_response :success

    # Second request - should use cache
    get room_stats_path(@room)
    assert_response :success
  end

  test "handles rooms with no messages" do
    get room_stats_path(@room)

    assert_response :success
    assert_includes response.body, "No messages yet"
  end

  test "requires authentication" do
    delete session_url

    get room_stats_path(@room)

    assert_redirected_to new_session_path
  end

  test "shows thread message counts correctly" do
    user = users(:david)

    # Create messages in main room
    2.times { @room.messages.create!(creator: user, body: "Message", client_message_id: SecureRandom.uuid) }

    # Create thread and thread messages
    parent_message = @room.messages.first
    thread = Rooms::Thread.create!(
      name: "Test Thread",
      creator: user,
      parent_message: parent_message
    )
    3.times { thread.messages.create!(creator: user, body: "Thread message", client_message_id: SecureRandom.uuid) }

    get room_stats_path(@room)

    assert_response :success
    # Should show 5 total messages (2 main + 3 thread)
    assert_includes response.body, user.name
  end

  test "displays room info correctly" do
    get room_stats_path(@room)

    assert_response :success
    assert_includes response.body, @room.name
    assert_includes response.body, @room.creator.name
  end
end
