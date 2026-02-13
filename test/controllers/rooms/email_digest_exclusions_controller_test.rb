require "test_helper"

class Rooms::EmailDigestExclusionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @room = rooms(:watercooler)
  end

  test "admin toggles exclude_from_digest on" do
    sign_in :david

    assert_changes -> { @room.reload.exclude_from_digest? }, from: false, to: true do
      put room_email_digest_exclusion_url(@room)
    end
  end

  test "admin toggles exclude_from_digest off" do
    sign_in :david
    @room.update!(exclude_from_digest: true)

    assert_changes -> { @room.reload.exclude_from_digest? }, from: true, to: false do
      put room_email_digest_exclusion_url(@room)
    end
  end

  test "responds with turbo_stream" do
    sign_in :david

    put room_email_digest_exclusion_url(@room, format: :turbo_stream)
    assert_response :success
  end

  test "non-admin is forbidden" do
    sign_in :jz

    put room_email_digest_exclusion_url(rooms(:designers))
    assert_response :forbidden
  end
end
