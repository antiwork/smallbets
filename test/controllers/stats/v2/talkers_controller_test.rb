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

      test "show displays correct period title in header" do
        [:today, :month, :year, :all_time].each do |period|
          get stats_v2_talker_path(period: period)

          assert_response :success
          assert_select 'h1', text: /Top Talkers/
        end
      end

      test "all_time show displays All Time card title" do
        get stats_v2_talker_path(period: :all_time)

        assert_response :success
        assert_select 'h2', text: 'All Time'
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

      # -- Breakdown card tests --

      test "today period shows daily breakdown cards grouped by month" do
        get stats_v2_talker_path(period: :today)

        assert_response :success
        # Should have section headings for months (e.g. "January 2026")
        assert_select 'h2.section-heading', minimum: 1
        # Should have grid cards for individual days
        assert_select 'div.card.grid-card', minimum: 1
      end

      test "month period shows monthly breakdown cards grouped by year" do
        get stats_v2_talker_path(period: :month)

        assert_response :success
        # Should have section headings for years
        assert_select 'h2.section-heading', minimum: 1
        # Should have grid cards for individual months
        assert_select 'div.card.grid-card', minimum: 1
      end

      test "year period shows yearly breakdown cards" do
        get stats_v2_talker_path(period: :year)

        assert_response :success
        # Should have grid cards for individual years
        assert_select 'div.card.grid-card', minimum: 1
      end

      test "all_time period shows single leaderboard card" do
        get stats_v2_talker_path(period: :all_time)

        assert_response :success
        # Should NOT have grid cards (single leaderboard, not breakdown)
        assert_select 'div.card.grid-card', count: 0
        # Should have a single card with table
        assert_select 'div.card', minimum: 1
        assert_select 'table.table', count: 1
      end

      test "breakdown cards use shared user_row partial with from_path" do
        room = rooms(:hq)
        3.times { |i| room.messages.create!(creator: @user, body: "Test #{i}", client_message_id: SecureRandom.uuid) }

        get stats_v2_talker_path(period: :month)

        assert_response :success
        # The user_row partial links with data-turbo-frame="_top" and from param
        assert_select 'a[data-turbo-frame="_top"]', minimum: 1
      end

      test "today breakdown only loads current month initially" do
        room = rooms(:hq)
        # Create a message last month — should NOT appear on initial load
        room.messages.create!(creator: @user, body: "Last month message", client_message_id: SecureRandom.uuid, created_at: 1.month.ago)

        get stats_v2_talker_path(period: :today)

        assert_response :success
        last_month = 1.month.ago.utc.strftime("%B %Y")
        # The previous month should not appear as a section heading (only via load more)
        assert_select 'h2.section-heading', text: last_month, count: 0
      end

      test "today breakdown shows load more when previous months exist" do
        room = rooms(:hq)
        room.messages.create!(creator: @user, body: "This month", client_message_id: SecureRandom.uuid)
        room.messages.create!(creator: @user, body: "Last month", client_message_id: SecureRandom.uuid, created_at: 1.month.ago)

        get stats_v2_talker_path(period: :today)

        assert_response :success
        assert_select '#load-more-months', count: 1
        assert_select '#load-more-months a', text: "Load previous month"
      end

      test "today breakdown hides load more when no previous months" do
        # Only messages this month — no previous month to load
        room = rooms(:hq)
        room.messages.create!(creator: @user, body: "This month", client_message_id: SecureRandom.uuid)
        Message.where("created_at < ?", Time.now.utc.beginning_of_month).delete_all

        get stats_v2_talker_path(period: :today)

        assert_response :success
        assert_select '#load-more-months', count: 0
      end

      test "daily_month endpoint renders turbo stream with month content" do
        room = rooms(:hq)
        month = 1.month.ago.utc.strftime("%Y-%m")
        room.messages.create!(creator: @user, body: "Test", client_message_id: SecureRandom.uuid, created_at: 1.month.ago)

        get stats_v2_talker_daily_month_path(month: month, format: :turbo_stream)

        assert_response :success
        assert_includes response.body, "daily-months"
        expected_heading = Date.parse("#{month}-01").strftime("%B %Y")
        assert_includes response.body, expected_heading
      end

      test "daily_month endpoint includes load more when earlier months exist" do
        room = rooms(:hq)
        room.messages.create!(creator: @user, body: "Old", client_message_id: SecureRandom.uuid, created_at: 2.months.ago)
        month = 1.month.ago.utc.strftime("%Y-%m")
        room.messages.create!(creator: @user, body: "Test", client_message_id: SecureRandom.uuid, created_at: 1.month.ago)

        get stats_v2_talker_daily_month_path(month: month, format: :turbo_stream)

        assert_response :success
        assert_includes response.body, "Load previous month"
      end

      test "daily_month endpoint removes load more when no earlier months" do
        earliest_month = Message.minimum("strftime('%Y-%m', created_at)")

        get stats_v2_talker_daily_month_path(month: earliest_month, format: :turbo_stream)

        assert_response :success
        assert_includes response.body, "remove"
        assert_includes response.body, "load-more-months"
        assert_not_includes response.body, "Load previous month"
      end

      test "daily_month requires authentication" do
        reset!

        get stats_v2_talker_daily_month_path(month: "2026-01", format: :turbo_stream)

        assert_redirected_to new_session_path
      end

      test "month and year periods do not show load more frame" do
        [:month, :year].each do |period|
          get stats_v2_talker_path(period: period)

          assert_response :success
          assert_select '#load-more-months', count: 0
        end
      end

      test "year breakdown shows users in each year card" do
        room = rooms(:hq)
        3.times { |i| room.messages.create!(creator: @user, body: "Test #{i}", client_message_id: SecureRandom.uuid) }

        get stats_v2_talker_path(period: :year)

        assert_response :success
        assert_select 'div.card.grid-card' do
          assert_select 'table tbody tr', minimum: 1
        end
      end
    end
  end
end
