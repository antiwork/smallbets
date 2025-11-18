require "test_helper"

class FeedControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
    @user1 = users(:david)
    @source_room = rooms(:pets)
    
    @room1 = Rooms::Open.create!(name: "Room 1", source_room: @source_room, creator: @user1)
    @card1 = FeedCard.create!(room: @room1, title: "Card 1", summary: "Summary 1", type: "automated")
    Message.create!(room: @room1, creator: @user1, body: ActionText::Content.new("Message"))

    FeedController.any_instance.stubs(:set_sidebar_memberships)
    FeedController.any_instance.stubs(:feed_nav_markup).returns("")
    FeedController.any_instance.stubs(:feed_sidebar_markup).returns("")
  end
  
  test "index renders successfully with default top view" do
    get root_path
    
    assert_response :success
  end
  
  test "index renders successfully with top view parameter" do
    get root_path, params: { view: "top" }
    
    assert_response :success
  end
  
  test "index renders successfully with new view parameter" do
    get root_path, params: { view: "new" }
    
    assert_response :success
  end
  
  test "index defaults to top for invalid view parameter" do
    get root_path, params: { view: "invalid" }
    
    assert_response :success
  end

  test "index returns digest cards as json" do
    get root_path, params: { view: "top" }, as: :json

    assert_response :success

    payload = response.parsed_body
    assert_kind_of Array, payload["feedCards"]
  end

  test "non-admin html requests are redirected to talk" do
    sign_in :kevin

    get root_path

    assert_redirected_to talk_path
    assert_equal 303, response.status
  end

  test "non-admin json requests are forbidden" do
    sign_in :kevin

    get root_path, as: :json

    assert_response :forbidden
  end
end
