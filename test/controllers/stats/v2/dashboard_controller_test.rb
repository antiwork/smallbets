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
    end
  end
end
