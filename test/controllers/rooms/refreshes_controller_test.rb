require "test_helper"

class Rooms::RefreshesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "refresh includes new messages since the last known" do
    travel_to 1.day.ago do
      @old_message = rooms(:hq).messages.create!(creator: users(:jason), body: "Old message", client_message_id: "old")
    end

    travel_to 1.minute.ago do
      @new_message = rooms(:hq).messages.create!(creator: users(:jason), body: "New message", client_message_id: "new")
      @old_message.touch
    end

    get room_refresh_url(rooms(:hq), format: :turbo_stream), params: { since: 10.minutes.ago.to_fs(:epoch) }

    assert_response :success

    assert_select "turbo-stream[action='append']" do
      assert_select "#" + dom_id(@new_message)
      assert_select "template", count: 1
    end

    assert_select "turbo-stream[action='replace']" do
      assert_select "#" + dom_id(@old_message)
      assert_select "template", count: 1
    end
  end

  test "non-admin users are redirected from conversation refreshes" do
    conversation = Rooms::Open.create!(name: "Digest Conversation Refresh", source_room: rooms(:hq), creator: users(:david))
    conversation.memberships.grant_to([users(:david), users(:kevin)])

    sign_in :kevin

    get room_refresh_url(conversation, format: :turbo_stream), params: { since: Time.current.to_fs(:epoch) }

    assert_redirected_to talk_path
    assert_equal 303, response.status
  end
end
