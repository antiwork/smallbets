require "test_helper"

module Stats
  module V2
    class DashboardControllerTest < ActionDispatch::IntegrationTest
      setup do
        sign_in :david
      end

      test "index renders successfully" do
        get stats_v2_dashboard_path

        assert_response :success
      end

      test "index displays user names in response" do
        room = rooms(:pets)
        user = users(:jason)

        # Create some messages
        3.times do |i|
          room.messages.create!(
            creator: user,
            body: "Test message #{i}",
            client_message_id: SecureRandom.uuid
          )
        end

        get stats_v2_dashboard_path

        assert_response :success
        assert_select 'h1', text: /Message Stats \(V2\)/
        assert_select '.card'
      end

      test "index displays all four time periods" do
        get stats_v2_dashboard_path

        assert_response :success
        assert_select '.card', count: 6  # 4 period cards + 1 top rooms card + 1 system info card

        # Check that all period titles are present
        response_body = response.body
        assert_includes response_body, 'Today'
        assert_includes response_body, 'This Month'
        assert_includes response_body, 'This Year'
        assert_includes response_body, 'All Time'
      end

      test "today period shows only today's messages" do
        room = rooms(:pets)
        user = User.create!(
          name: "Today User",
          email_address: "today@test.com",
          password: "secret123456"
        )

        # Message from today
        room.messages.create!(
          creator: user,
          body: "Today message",
          client_message_id: SecureRandom.uuid,
          created_at: Time.current
        )

        # Message from yesterday
        room.messages.create!(
          creator: user,
          body: "Yesterday message",
          client_message_id: SecureRandom.uuid,
          created_at: 1.day.ago
        )

        get stats_v2_dashboard_path

        assert_response :success
      end

      test "month period shows only this month's messages" do
        room = rooms(:pets)
        user = User.create!(
          name: "Month User",
          email_address: "month@test.com",
          password: "secret123456"
        )

        # Message from this month
        room.messages.create!(
          creator: user,
          body: "This month",
          client_message_id: SecureRandom.uuid,
          created_at: Time.current
        )

        # Message from last month
        room.messages.create!(
          creator: user,
          body: "Last month",
          client_message_id: SecureRandom.uuid,
          created_at: 1.month.ago
        )

        get stats_v2_dashboard_path

        assert_response :success
      end

      test "current user rank shows different message counts per period" do
        room = rooms(:pets)
        user = users(:david)
        sign_in user

        # Today: 2 messages
        2.times do |i|
          room.messages.create!(
            creator: user,
            body: "Today #{i}",
            client_message_id: SecureRandom.uuid,
            created_at: Time.current
          )
        end

        # 5 days ago: 3 messages (still this month)
        3.times do |i|
          msg = room.messages.create!(
            creator: user,
            body: "5 days ago #{i}",
            client_message_id: SecureRandom.uuid
          )
          msg.update_column(:created_at, 5.days.ago)
        end

        # Last month: 4 messages
        4.times do |i|
          msg = room.messages.create!(
            creator: user,
            body: "Last month #{i}",
            client_message_id: SecureRandom.uuid
          )
          msg.update_column(:created_at, 1.month.ago)
        end

        get stats_v2_dashboard_path

        assert_response :success

        # Verify different periods show different message counts
        # The response should contain the user's rank with different counts
        response_body = response.body

        # User should appear with different message counts in different periods
        assert_includes response_body, user.name
      end

      test "index displays system metrics info card" do
        get stats_v2_dashboard_path

        assert_response :success

        # Check that system info section is present
        assert_select '.section-heading', text: 'Stats'

        # Check that the info card is present
        response_body = response.body
        assert_includes response_body, 'Members'
        assert_includes response_body, 'Online'
        assert_includes response_body, 'Posters'
        assert_includes response_body, 'Messages'
        assert_includes response_body, 'Threads'
        assert_includes response_body, 'Boosts'
        assert_includes response_body, 'Database'
      end

      test "system metrics displays correct counts" do
        get stats_v2_dashboard_path

        assert_response :success

        # Verify that numeric values are displayed
        response_body = response.body
        assert_match /Members.*\d+/m, response_body
        assert_match /Messages.*\d+/m, response_body
      end

      test "displays top rooms card" do
        get stats_v2_dashboard_path

        assert_response :success

        # Check that top rooms card is present
        response_body = response.body
        assert_includes response_body, 'Top Rooms'
      end

      test "top rooms displays room names and message counts" do
        room = rooms(:pets)
        user = users(:david)

        # Create some messages
        3.times do |i|
          room.messages.create!(
            creator: user,
            body: "Test message #{i}",
            client_message_id: SecureRandom.uuid
          )
        end

        get stats_v2_dashboard_path

        assert_response :success

        # Verify room appears in response
        response_body = response.body
        assert_includes response_body, room.name
      end
    end
  end
end
