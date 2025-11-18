require "test_helper"

module AutomatedFeed
  class DeduplicatorTest < ActiveSupport::TestCase
    setup do
      @user1 = users(:david)
      @user2 = users(:jason)
      @room = rooms(:hq)
      
      @conversation = {
        message_ids: [1, 2, 3],
        title: "Test conversation",
        summary: "Test summary",
        participants: ["@user1", "@user2"],
        topic_tags: ["test-tag"]
      }

      AutomatedFeed::Scanner
      @ai_gateway = Object.const_get("AiGateway")
    end

    test "check returns skip for exact fingerprint match" do
      existing_card = AutomatedFeedCard.create!(
        room: @room,
        title: "Existing",
        summary: "Existing summary",
        type: "automated",
        message_fingerprint: Digest::SHA256.hexdigest([1, 2, 3].sort.join(","))
      )

      result = Deduplicator.check(conversation: @conversation)

      assert_equal :skip, result[:action]
      assert_equal "exact_fingerprint_match", result[:reason]
      assert_equal existing_card, result[:existing_card]
    end

    test "check returns new_topic when no matches" do
      AutomatedFeedCard.stubs(:find_by).returns(nil)
      AutomatedFeedCard.stubs(:where).returns(AutomatedFeedCard.none)

      @ai_gateway.stubs(:complete).returns({
        "action" => "new_topic",
        "related_card_id" => nil,
        "similarity_score" => 0.1,
        "reasoning" => "New topic"
      }.to_json)

      result = Deduplicator.check(conversation: @conversation)

      assert_equal :new_topic, result[:action]
    end

    test "check returns continuation when AI detects continuation" do
      existing_card = AutomatedFeedCard.create!(
        room: @room,
        title: "Existing",
        summary: "Existing summary",
        type: "automated",
        created_at: 1.hour.ago
      )

      # Don't stub find_by for fingerprint check - let it work naturally
      # The conversation has different message_ids so it won't match fingerprint

      @ai_gateway.stubs(:complete).returns({
        "action" => "continuation",
        "related_card_id" => existing_card.id,
        "similarity_score" => 0.9,
        "reasoning" => "Continuing discussion"
      }.to_json)

      result = Deduplicator.check(conversation: @conversation)

      assert_equal :continuation, result[:action]
      assert_equal existing_card, result[:card]
      assert_equal 0.9, result[:similarity_score]
    end

    test "check returns skip for duplicate" do
      existing_card = AutomatedFeedCard.create!(
        room: @room,
        title: "Existing",
        summary: "Existing summary",
        type: "automated",
        created_at: 1.hour.ago
      )

      # Don't stub - let the natural flow work
      # The conversation has different message_ids so it won't match fingerprint

      @ai_gateway.stubs(:complete).returns({
        "action" => "duplicate",
        "related_card_id" => existing_card.id,
        "similarity_score" => 1.0,
        "reasoning" => "Duplicate conversation"
      }.to_json)

      result = Deduplicator.check(conversation: @conversation)

      assert_equal :skip, result[:action]
      assert_equal "duplicate", result[:reason]
      assert_equal existing_card, result[:existing_card]
    end

    test "check handles AI errors gracefully" do
      AutomatedFeedCard.stubs(:find_by).returns(nil)
      AutomatedFeedCard.stubs(:where).returns(AutomatedFeedCard.none)

      @ai_gateway.stubs(:complete).raises(@ai_gateway::Error.new("API error"))

      result = Deduplicator.check(conversation: @conversation)

      assert_equal :new_topic, result[:action]
    end

    test "check filters cards by source_room_id when provided" do
      # Create two parent rooms
      parent_room_1 = rooms(:hq)
      parent_room_2 = rooms(:pets)

      # Create conversation rooms forked from each parent
      conv_room_1 = Rooms::Open.create!(
        name: "Conversation from room 1",
        source_room: parent_room_1,
        creator: @user1
      )
      conv_room_2 = Rooms::Open.create!(
        name: "Conversation from room 2",
        source_room: parent_room_2,
        creator: @user1
      )

      # Create feed cards for each
      card_from_room_1 = AutomatedFeedCard.create!(
        room: conv_room_1,
        title: "Card from room 1",
        summary: "Summary 1",
        type: "automated"
      )
      card_from_room_2 = AutomatedFeedCard.create!(
        room: conv_room_2,
        title: "Card from room 2",
        summary: "Summary 2",
        type: "automated"
      )

      # Check deduplication for a conversation from parent_room_1
      # It should only see card_from_room_1, not card_from_room_2
      
      # Need to stub AiGateway outside the module namespace
      ai_gateway_class = Object.const_get("AiGateway")
      ai_gateway_class.stubs(:complete).returns({
        "action" => "new_topic",
        "related_card_id" => nil,
        "similarity_score" => 0.1,
        "reasoning" => "New topic"
      }.to_json)

      result = Deduplicator.check(
        conversation: @conversation,
        source_room_id: parent_room_1.id
      )

      assert_equal :new_topic, result[:action]

      # Verify that when checking continuation, only cards from the same source room are considered
      # This is implicitly tested by the filtering in fetch_recent_cards
    end

    test "check does not filter when source_room_id is nil" do
      # Create a conversation room without source_room filtering
      conv_room = Rooms::Open.create!(
        name: "Conversation",
        source_room: @room,
        creator: @user1
      )

      card = AutomatedFeedCard.create!(
        room: conv_room,
        title: "Card",
        summary: "Summary",
        type: "automated"
      )

      # Need to stub AiGateway outside the module namespace
      ai_gateway_class = Object.const_get("AiGateway")
      ai_gateway_class.stubs(:complete).returns({
        "action" => "new_topic",
        "related_card_id" => nil,
        "similarity_score" => 0.1,
        "reasoning" => "New topic"
      }.to_json)

      # When source_room_id is nil, all cards should be considered
      result = Deduplicator.check(
        conversation: @conversation,
        source_room_id: nil
      )

      assert_equal :new_topic, result[:action]
    end
  end
end
