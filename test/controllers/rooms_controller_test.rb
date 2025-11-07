require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "index redirects to the user's last room" do
    get rooms_url
    assert_redirected_to room_url(users(:david).rooms.last)
  end

  test "show" do
    get room_url(users(:david).rooms.last)
    assert_response :success
  end

  test "shows records the last room visited in a cookie" do
    get room_url(users(:david).rooms.last)
    assert response.cookies[:last_room] = users(:david).rooms.last.id
  end

  test "destroy" do
    assert_turbo_stream_broadcasts :rooms, count: 2 do
      assert_difference -> { Room.active.count }, -1 do
        delete room_url(rooms(:designers))
      end
    end
  end

  test "destroy only allowed for creators or those who can administer" do
    sign_in :jz

    assert_no_difference -> { Room.count } do
      delete room_url(rooms(:designers))
      assert_response :forbidden
    end

    rooms(:designers).update! creator: users(:jz)

    assert_difference -> { Room.active.count }, -1 do
      delete room_url(rooms(:designers))
    end
  end

  test "non-admin users are redirected away from conversation rooms" do
    conversation = Rooms::Open.create!(name: "Digest Conversation", source_room: rooms(:hq), creator: users(:david))
    conversation.memberships.grant_to([users(:david), users(:kevin)])

    sign_in :kevin

    get room_url(conversation)

    assert_redirected_to talk_path
    assert_equal 303, response.status
  end

  test "administrators can view conversation rooms" do
    conversation = Rooms::Open.create!(name: "Digest Conversation (Admin)", source_room: rooms(:hq), creator: users(:david))
    conversation.memberships.grant_to(users(:david))

    get room_url(conversation)

    assert_response :success
  end
end
