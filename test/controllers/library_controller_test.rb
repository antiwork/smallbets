require "test_helper"

class LibraryControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "once.campfire.test"
    sign_in :david
    
    # Ensure rooms have last_active_at set for sidebar rendering
    Room.where(last_active_at: nil).update_all(last_active_at: Time.current)
  end

  test "index renders inertia payload" do
    get library_url, headers: {
      "X-Inertia" => "true",
      "X-Inertia-Version" => ViteRuby.digest
    }

    assert_response :success
    json = response.parsed_body

    assert_equal "library/index", json["component"]
    assert json["props"].key?("sections")
    assert json["props"].key?("continueWatching")
  end

  test "index renders inertia response by default" do
    get library_url

    assert_response :success
  end
end

