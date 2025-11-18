require "test_helper"

module HomeFeed
  class RankerTest < ActiveSupport::TestCase
    setup do
      @user1 = users(:david)
      @user2 = users(:jason)
      @source_room = rooms(:pets)
      
      @room1 = Rooms::Open.create!(name: "Room 1", source_room: @source_room, creator: @user1)
      @room2 = Rooms::Open.create!(name: "Room 2", source_room: @source_room, creator: @user1)
      @room3 = Rooms::Open.create!(name: "Room 3", source_room: @source_room, creator: @user1)
      
      @card1 = FeedCard.create!(room: @room1, title: "Card 1", summary: "Summary 1", type: "automated")
      @card2 = FeedCard.create!(room: @room2, title: "Card 2", summary: "Summary 2", type: "automated")
      @card3 = FeedCard.create!(room: @room3, title: "Card 3", summary: "Summary 3", type: "automated")
      
      @msg1_1 = Message.create!(room: @room1, creator: @user1, body: ActionText::Content.new("Message 1"), created_at: 1.hour.ago)
      @msg1_2 = Message.create!(room: @room1, creator: @user2, body: ActionText::Content.new("Message 2"), created_at: 1.hour.ago)
      Boost.create!(message: @msg1_1, booster: @user2, content: "👍")
      Boost.create!(message: @msg1_2, booster: @user1, content: "❤️")
      Bookmark.create!(message: @msg1_1, user: @user2)
      
      @msg2_1 = Message.create!(room: @room2, creator: @user1, body: ActionText::Content.new("Message 1"), created_at: 2.days.ago)
      Boost.create!(message: @msg2_1, booster: @user2, content: "👍")
      
      @msg3_1 = Message.create!(room: @room3, creator: @user1, body: ActionText::Content.new("Message 1"), created_at: 30.minutes.ago)
    end
    
    test "top returns cards ordered by score" do
      result = Ranker.top(limit: 3)
      
      assert_equal 3, result.length
      # Room 1 should rank highest (high activity + recent)
      assert_equal @card1.id, result.first.id
    end
    
    test "top prioritizes activity over recency" do
      # Create room with high activity but older
      room4 = Rooms::Open.create!(name: "Room 4", source_room: @source_room, creator: @user1)
      card4 = FeedCard.create!(room: room4, title: "Card 4", summary: "Summary 4", type: "automated")
      
      5.times do |i|
        msg = Message.create!(room: room4, creator: @user1, body: ActionText::Content.new("Message #{i}"), created_at: 3.days.ago)
        Boost.create!(message: msg, booster: @user2, content: "👍")
      end
      
      result = Ranker.top(limit: 4)
      
      card_ids = result.map(&:id)
      assert card_ids.index(card4.id) < card_ids.index(@card3.id), "High activity room should rank higher than low activity room"
    end
    
    test "new returns cards ordered by earliest message time descending" do
      result = Ranker.new(limit: 3)
      
      assert_equal 3, result.length
      assert_equal @card3.id, result.first.id
      assert_equal @card1.id, result.second.id
      assert_equal @card2.id, result.last.id
    end
    
    test "new excludes cards without messages" do
      room4 = Rooms::Open.create!(name: "Room 4", source_room: @source_room, creator: @user1)
      card4 = FeedCard.create!(room: room4, title: "Card 4", summary: "Summary 4", type: "automated")
      
      result = Ranker.new(limit: 10)
      
      assert_not_includes result.map(&:id), card4.id
    end
    
    test "top handles empty results" do
      FeedCard.destroy_all
      
      result = Ranker.top(limit: 10)
      
      assert_equal [], result
    end
    
    test "new handles empty results" do
      FeedCard.destroy_all
      
      result = Ranker.new(limit: 10)
      
      assert_equal [], result
    end
    
    test "top limits results correctly" do
      result = Ranker.top(limit: 2)
      
      assert_equal 2, result.length
    end
    
    test "new limits results correctly" do
      result = Ranker.new(limit: 2)
      
      assert_equal 2, result.length
    end
  end
end
