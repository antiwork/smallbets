# frozen_string_literal: true

require "test_helper"

module Stats
  module V2
    class BaseControllerTest < ActionDispatch::IntegrationTest
      test "PERIODS constant contains all valid periods" do
        assert_equal [:today, :month, :year, :all_time], BaseController::PERIODS
      end

      test "period_title returns correct titles for all periods" do
        assert_equal "Today", BaseController.period_title(:today)
        assert_equal "This Month", BaseController.period_title(:month)
        assert_equal "This Year", BaseController.period_title(:year)
        assert_equal "All Time", BaseController.period_title(:all_time)
      end

      test "period_title returns nil for invalid period" do
        assert_nil BaseController.period_title(:invalid)
      end
    end
  end
end
