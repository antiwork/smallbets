require "test_helper"

class OauthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
    @auth_hash = {
      "uid" => "12345",
      "info" => {
        "email" => @user.email_address,
        "nickname" => "david_twitter"
      }
    }
  end

  test "should connect X account when user is signed in" do
    sign_in @user

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:twitter2] = OmniAuth::AuthHash.new(@auth_hash)

    get "/auth/twitter2/callback"

    @user.reload
    assert_equal "12345", @user.twitter_uid
    assert_redirected_to user_profile_path
    assert_equal "X account connected successfully!", flash[:notice]
  end

  test "should sign in existing user with X account" do
    @user.update!(twitter_uid: "12345")

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:twitter2] = OmniAuth::AuthHash.new(@auth_hash)

    get "/auth/twitter2/callback"

    assert_redirected_to root_path
    assert @user.sessions.exists?
  end

  test "should link X account to existing user by email during sign in" do
    assert_nil @user.twitter_uid

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:twitter2] = OmniAuth::AuthHash.new(@auth_hash)

    get "/auth/twitter2/callback"

    @user.reload
    assert_equal "12345", @user.twitter_uid
    assert_redirected_to root_path
  end

  test "should redirect to signup when no user found" do
    @auth_hash["info"]["email"] = "newuser@example.com"

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:twitter2] = OmniAuth::AuthHash.new(@auth_hash)

    get "/auth/twitter2/callback"

    assert_redirected_to new_session_path
    assert_equal "No account found. Please sign up first or use email login.", flash[:alert]
  end

  test "should handle authentication failure gracefully" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:twitter2] = :invalid_credentials

    get "/auth/twitter2/callback"

    assert_redirected_to new_session_path
    assert_equal "Authentication failed.", flash[:alert]
  end

  test "should disconnect X account" do
    sign_in @user
    @user.update!(twitter_uid: "12345")

    post "/auth/twitter2/disconnect"

    @user.reload
    assert_nil @user.twitter_uid
    assert_redirected_to user_profile_path
    assert_equal "X account disconnected.", flash[:notice]
  end

  test "should require authentication for disconnect" do
    post "/auth/twitter2/disconnect"
    assert_redirected_to new_session_path
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:twitter2] = nil
  end
end