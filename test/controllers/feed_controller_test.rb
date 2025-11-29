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

  test "feed cards include deduplicated emoji reactions from original messages" do
    source_room = rooms(:watercooler)
    originals = [
      create_original_message(source_room, "Hello"),
      create_original_message(source_room, "World")
    ]

    Boost.create!(message: originals[0], content: "🔥", booster: @user1)
    Boost.create!(message: originals[0], content: "🔥", booster: users(:jason))
    Boost.create!(message: originals[1], content: "🔥", booster: users(:kevin))
    Boost.create!(message: originals[1], content: "😎", booster: @user1)

    room = build_conversation_room(source_room, originals, name: "Dedup Test")
    reactions = fetch_reactions_for(room)

    assert_equal ["🔥", "😎"], reactions
  end

  test "feed cards exclude text reactions and only show emoji-only reactions" do
    source_room = rooms(:watercooler)
    original_message = create_original_message(source_room, "Testing")

    Boost.create!(message: original_message, content: "🎉", booster: @user1)
    Boost.create!(message: original_message, content: "Great job!", booster: users(:jason))
    Boost.create!(message: original_message, content: "👍", booster: users(:kevin))
    Boost.create!(message: original_message, content: "Nice work 🔥", booster: @user1)

    room = build_conversation_room(source_room, [ original_message ], name: "Filter Test")
    reactions = fetch_reactions_for(room)

    assert_equal ["🎉", "👍"], reactions.sort
  end

  test "feed cards show reactions ordered by count with most popular first" do
    source_room = rooms(:watercooler)
    original_message = create_original_message(source_room, "Popular")

    3.times { Boost.create!(message: original_message, content: "🔥", booster: @user1) }
    2.times { Boost.create!(message: original_message, content: "👍", booster: @user1) }
    Boost.create!(message: original_message, content: "😎", booster: @user1)

    room = build_conversation_room(source_room, [ original_message ], name: "Ordering Test")
    reactions = fetch_reactions_for(room)

    assert_equal ["🔥", "👍", "😎"], reactions
  end

  private

  def create_original_message(source_room, body)
    Message.create!(room: source_room, creator: @user1, body: ActionText::Content.new(body))
  end

  def build_conversation_room(source_room, originals, name:)
    room = Rooms::Open.create!(name:, source_room:, creator: @user1)
    originals.each do |message|
      Message.create!(room:, creator: @user1, original_message: message)
    end
    FeedCard.create!(room:, title: name, summary: "Test", type: "automated")
    room
  end

  def fetch_reactions_for(room)
    get root_path, params: { view: "top" }, as: :json
    assert_response :success

    payload = response.parsed_body
    card = payload["feedCards"].find { |feed_card| feed_card.dig("room", "id") == room.id }
    assert_not_nil card
    card.dig("room", "reactions")
  end
end
