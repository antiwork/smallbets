require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "redirects to the first created open room" do
    get talk_url

    assert_redirected_to room_url(Room.opens.order(:created_at).first)
  end

  test "redirects to the first created open room, no matter what the last visited room was" do
    cookies[:last_room] = rooms(:watercooler).id

    get talk_url

    assert_redirected_to room_url(Room.opens.order(:created_at).first)
  end
end
