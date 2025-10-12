require "test_helper"

class OauthUserFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
    @twitter_auth = {
      "uid" => "twitter_12345",
      "info" => {
        "email" => @user.email_address,
        "nickname" => "david_x"
      }
    }
  end

  test "complete user flow: connect X account then sign in with X" do
    sign_in @user
    
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:twitter2] = OmniAuth::AuthHash.new(@twitter_auth)
    
    get "/auth/twitter2/callback"
    
    @user.reload
    assert_equal "twitter_12345", @user.twitter_uid
    assert_equal "X account connected successfully!", flash[:notice]
    
    delete session_path
    assert_redirected_to unauthenticated_root_path
    
    get "/auth/twitter2/callback"
    
    assert_redirected_to root_path
    
    assert @user.sessions.exists?
  end

  test "user without X account tries to sign in with X" do
    @twitter_auth["info"]["email"] = "newuser@example.com"
    
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:twitter2] = OmniAuth::AuthHash.new(@twitter_auth)
    
    get "/auth/twitter2/callback"
    
    assert_redirected_to new_session_path
    assert_equal "No account found. Please sign up first or use email login.", flash[:alert]
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:twitter2] = nil
  end
end