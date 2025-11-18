require "test_helper"

module Library
  class WatchHistoriesControllerTest < ActionDispatch::IntegrationTest
    setup do
      host! "once.campfire.test"

      sign_in :david
      @session = library_sessions(:design_systems_intro)
    end

    test "create records playback progress" do
      assert_difference -> { LibraryWatchHistory.count }, +1 do
        post library_session_watch_history_path(@session), params: {
          watch: {
            played_seconds: 45,
            duration_seconds: 120,
            completed: false
          }
        }, as: :json
      end

      assert_response :created
      history = LibraryWatchHistory.last
      assert_equal 45, history.played_seconds
      assert_equal 120, history.duration_seconds
      assert_not history.completed?
    end

    test "create accepts camelCase payload" do
      post library_session_watch_history_path(@session), params: {
        watch: {
          playedSeconds: 4.526,
          durationSeconds: 120.3
        }
      }, as: :json

      assert_response :created
      history = LibraryWatchHistory.last
      assert_equal 4, history.played_seconds
      assert_equal 120, history.duration_seconds
    end

    test "update toggles completion" do
      history = LibraryWatchHistory.create!(
        library_session: @session,
        user: users(:david),
        played_seconds: 30
      )

      patch library_session_watch_history_path(@session), params: {
        watch: {
          played_seconds: 120,
          duration_seconds: 120,
          completed: true
        }
      }, as: :json

      assert_response :success
      history.reload
      assert history.completed?
      assert_equal 120, history.played_seconds
    end

    test "rejects invalid payload" do
      post library_session_watch_history_path(@session), params: {
        watch: {
          played_seconds: -1
        }
      }, as: :json

      assert_response :unprocessable_entity
      assert_includes response.parsed_body["error"], "greater than or equal to 0"
    end
  end
end
