require "test_helper"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.silence_get_warning = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:twitter2] = nil
  end

  def mock_auth_hash(uid: "123456789", nickname: "testuser")
    OmniAuth::AuthHash.new({
      "provider" => "twitter2",
      "uid" => uid,
      "info" => {
        "nickname" => nickname,
        "image" => "https://pbs.twimg.com/profile_images/test.jpg"
      },
      "credentials" => {
        "token" => "test_token",
        "refresh_token" => "test_refresh"
      }
    })
  end

  test "twitter callback for login signs in user with linked X account" do
    user = users(:david)
    user.update!(twitter_uid: "123456789", twitter_oauth_token: "token")

    OmniAuth.config.mock_auth[:twitter2] = mock_auth_hash

    post "/auth/twitter2/login"
    assert_response :success

    get "/auth/twitter2/callback"

    assert_redirected_to root_path
    assert_equal "Signed in with X successfully!", flash[:notice]
  end

  test "twitter callback for login rejects user without linked X account" do
    OmniAuth.config.mock_auth[:twitter2] = mock_auth_hash(uid: "nonexistent")

    post "/auth/twitter2/login"
    get "/auth/twitter2/callback"

    assert_redirected_to new_session_path
    assert_equal "No account found with this X account. Please sign in with email first and connect your X account.", flash[:alert]
  end

  test "twitter callback for connect redirects when not signed in" do
    OmniAuth.config.mock_auth[:twitter2] = mock_auth_hash

    get "/auth/twitter2/callback"

    assert_redirected_to new_session_path
    assert_equal "Please sign in first to connect your X account.", flash[:alert]
  end

  test "disconnect clears X account data" do
    sign_in :david
    user = users(:david)
    user.update!(
      twitter_uid: "123456789",
      twitter_oauth_token: "token",
      twitter_oauth_refresh_token: "refresh",
      twitter_screen_name: "testuser",
      twitter_profile_image: "https://example.com/image.jpg",
      twitter_connected_at: Time.current
    )

    delete "/auth/twitter/disconnect"

    assert_redirected_to user_profile_path("me")
    assert_equal "X account disconnected successfully!", flash[:notice]

    user.reload
    assert_nil user.twitter_uid
    assert_nil user.twitter_oauth_token
    assert_nil user.twitter_screen_name
    assert_nil user.twitter_connected_at
  end

  test "disconnect requires authentication" do
    delete "/auth/twitter/disconnect"

    assert_redirected_to new_session_path
  end

  test "initiate_login renders auto-submit form" do
    post "/auth/twitter2/login"

    assert_response :success
    assert_includes response.body, 'action="/auth/twitter2"'
  end

  test "failure redirects with error message" do
    get "/auth/failure", params: { message: "access_denied" }

    assert_redirected_to user_profile_path("me")
    assert_equal "X authentication failed: access_denied", flash[:alert]
  end

  test "user twitter_uid must be unique" do
    users(:david).update!(twitter_uid: "123456789")

    user = users(:jason)
    user.twitter_uid = "123456789"

    assert_not user.valid?
    assert_includes user.errors[:twitter_uid], "has already been taken"
  end

  test "twitter_connected? returns true when uid and connected_at present" do
    user = users(:david)
    user.update!(twitter_uid: "123", twitter_connected_at: Time.current)

    assert user.twitter_connected?
  end

  test "twitter_connected? returns false when uid missing" do
    user = users(:david)
    user.update!(twitter_uid: nil, twitter_connected_at: Time.current)

    assert_not user.twitter_connected?
  end

  test "twitter_connected? returns false when connected_at missing" do
    user = users(:david)
    user.update!(twitter_uid: "123", twitter_connected_at: nil)

    assert_not user.twitter_connected?
  end
end
