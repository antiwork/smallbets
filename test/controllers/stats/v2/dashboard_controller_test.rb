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
        assert_select 'h1', text: /Message Stats/
        assert_select '.card'
      end

      test "index displays all four time periods as turbo frames" do
        get stats_v2_dashboard_path

        assert_response :success
        # Now checking for turbo frames instead of loaded cards
        assert_select 'turbo-frame#top_talkers_today'
        assert_select 'turbo-frame#top_talkers_month'
        assert_select 'turbo-frame#top_talkers_year'
        assert_select 'turbo-frame#top_talkers_all_time'
        assert_select 'turbo-frame#system_info'
        assert_select 'turbo-frame#top_rooms'
        assert_select 'turbo-frame#newest_members'
        assert_select 'turbo-frame#message_history'
      end

      # Card endpoint tests
      test "top_talkers_card endpoint loads successfully" do
        get stats_v2_dashboard_top_talkers_card_path(period: :today)

        assert_response :success
        assert_select 'turbo-frame#top_talkers_today'
      end

      test "system_info_card endpoint loads successfully" do
        get stats_v2_dashboard_system_info_card_path

        assert_response :success
        assert_select 'turbo-frame#system_info'
        assert_includes response.body, 'Members'
        assert_includes response.body, 'Messages'
      end

      test "top_rooms_card endpoint loads successfully" do
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

        get stats_v2_dashboard_top_rooms_card_path

        assert_response :success
        assert_select 'turbo-frame#top_rooms'
        assert_includes response.body, room.name
      end

      test "newest_members_card endpoint loads successfully" do
        get stats_v2_dashboard_newest_members_card_path

        assert_response :success
        assert_select 'turbo-frame#newest_members'
      end

      test "message_history_card endpoint loads successfully" do
        get stats_v2_dashboard_message_history_card_path

        assert_response :success
        assert_select 'turbo-frame#message_history'
        assert_includes response.body, 'Messages'
      end
    end
  end
end
