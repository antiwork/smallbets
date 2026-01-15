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
        assert_select '.card', count: 4

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
    end
  end
end
