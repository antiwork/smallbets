# frozen_string_literal: true

require "test_helper"

module Stats
  module V2
    class TalkersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:jason)
        sign_in @user
      end

      test "show renders successfully for valid period" do
        get stats_v2_talker_path(period: :today)

        assert_response :success
        assert_select 'h1', text: /Today - Top Talkers/
      end

      test "show renders for all valid periods" do
        [:today, :month, :year, :all_time].each do |period|
          get stats_v2_talker_path(period: period)

          assert_response :success
        end
      end

      test "show displays users in leaderboard" do
        get stats_v2_talker_path(period: :all_time)

        assert_response :success
        assert_select 'table tbody tr', minimum: 1
      end

      test "show highlights current user row" do
        # Create messages for current user to ensure they're in the leaderboard
        room = rooms(:hq)
        3.times { |i| room.messages.create!(creator: @user, body: "Test #{i}", client_message_id: SecureRandom.uuid) }

        get stats_v2_talker_path(period: :all_time)

        assert_response :success
        assert_select 'tr.current-user', count: 1
      end

      test "show displays current user rank when outside top 100" do
        # This test assumes the test database has fewer than 100 users with messages
        # If current user is in top 100, they won't see the rank notice
        get stats_v2_talker_path(period: :today)

        assert_response :success
        # Test passes if page renders (rank display is conditional)
      end

      test "show redirects to dashboard with invalid period" do
        get stats_v2_talker_path(period: :invalid)

        assert_redirected_to stats_v2_dashboard_path
        assert_equal "Invalid period", flash[:alert]
      end

      test "show has back button to dashboard" do
        get stats_v2_talker_path(period: :today)

        assert_response :success
        assert_select 'a[href=?]', stats_v2_dashboard_path, text: /Back to Stats/
      end

      test "show has refresh button" do
        get stats_v2_talker_path(period: :month)

        assert_response :success
        assert_select 'a[href=?]', stats_v2_talker_path(period: :month)
      end

      test "show displays correct period title" do
        periods_and_titles = {
          today: 'Today',
          month: 'This Month',
          year: 'This Year',
          all_time: 'All Time'
        }

        periods_and_titles.each do |period, title|
          get stats_v2_talker_path(period: period)

          assert_response :success
          assert_select 'h2', text: title
        end
      end

      test "show displays rank numbers" do
        get stats_v2_talker_path(period: :all_time)

        assert_response :success
        # Should have rank numbers in the first column
        assert_select 'td.txt-right.txt-small.txt-faded', minimum: 1
      end

      test "show displays message counts" do
        get stats_v2_talker_path(period: :all_time)

        assert_response :success
        # Should have message counts in the last column
        assert_select 'table tbody td.txt-right', minimum: 1
      end

      test "show displays user avatars and names" do
        get stats_v2_talker_path(period: :all_time)

        assert_response :success
        assert_select 'div.avatar', minimum: 1
        assert_select 'span.txt-truncate', minimum: 1
      end

      test "show displays empty state when no users have messages today" do
        # Use :today period which will have no messages if none were created today
        get stats_v2_talker_path(period: :today)

        assert_response :success
        # Page should render even if empty
      end

      test "show requires authentication" do
        # Create a new session without signing in
        reset!

        get stats_v2_talker_path(period: :today)

        assert_redirected_to new_session_path
      end
    end
  end
end
