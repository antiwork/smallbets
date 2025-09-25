require "test_helper"

class SessionsOauthTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
    @account = accounts(:signal)
    
    # Setup OmniAuth test mode
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:twitter] = nil
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:twitter] = nil
  end

  test "oauth callback connects account for signed in user" do
    # Set up session to simulate signed in user
    post "/", params: {}, session: { user_id: @user.id }
    
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new({
      provider: 'twitter',
      uid: '123456789',
      info: {
        name: 'Test User',
        nickname: 'testuser',
        image: 'http://example.com/avatar.jpg'
      }
    })
    
    get "/auth/twitter/callback"
    
    assert_redirected_to user_profile_url
    assert_equal "Successfully connected your Twitter account!", flash[:notice]
    
    @user.reload
    assert_equal 'twitter', @user.provider
    assert_equal '123456789', @user.uid
    assert @user.oauth_connected?
  end

  test "oauth callback authenticates user with existing oauth account" do
    @user.update!(provider: 'twitter', uid: '123456789')
    
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new({
      provider: 'twitter',
      uid: '123456789',
      info: {
        name: 'Test User',
        nickname: 'testuser'
      }
    })

    get "/auth/twitter/callback"
    
    assert_redirected_to root_url
    assert_equal "Successfully signed in with Twitter!", flash[:notice]
    assert_equal @user.id, session[:user_id]
  end

  test "oauth callback stores data in session for unknown user" do
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new({
      provider: 'twitter',
      uid: '999999999',
      info: {
        name: 'Unknown User',
        nickname: 'unknown'
      }
    })

    get "/auth/twitter/callback"
    
    assert_redirected_to new_session_url
    assert_equal "Please sign in with your email to connect your Twitter account.", flash[:notice]
    
    assert_equal 'twitter', session[:oauth_data]['provider']
    assert_equal '999999999', session[:oauth_data]['uid']
  end

  test "oauth callback prevents connecting account already linked to another user" do
    other_user = users(:jason)
    other_user.update!(provider: 'twitter', uid: '123456789')
    
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new({
      provider: 'twitter',
      uid: '123456789',
      info: { name: 'Test User' }
    })

    get "/auth/twitter/callback", session: { user_id: @user.id }
    
    assert_redirected_to user_profile_url
    assert_equal "Failed to connect your Twitter account. It may already be connected to another user.", flash[:alert]
    
    @user.reload
    assert_nil @user.provider
    assert_nil @user.uid
    refute @user.oauth_connected?
  end

  test "oauth disconnect removes oauth connection" do
    @user.update!(provider: 'twitter', uid: '123456789')
    
    delete "/auth/disconnect", session: { user_id: @user.id }
    
    assert_redirected_to user_profile_url
    assert_equal "Successfully disconnected your X (Twitter) account.", flash[:notice]
    
    @user.reload
    assert_nil @user.provider
    assert_nil @user.uid
    refute @user.oauth_connected?
  end

  test "oauth disconnect with no connected account shows error" do
    delete "/auth/disconnect", session: { user_id: @user.id }
    
    assert_redirected_to user_profile_url
    assert_equal "No OAuth account is connected.", flash[:alert]
  end

  test "oauth failure redirects with error message" do
    OmniAuth.config.mock_auth[:twitter] = :invalid_credentials
    
    get "/auth/failure"
    
    assert_redirected_to new_session_url
    assert_equal "Authentication failed. Please try again.", flash[:alert]
  end

  test "oauth callback offers to connect account for existing user with matching email" do
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new({
      provider: 'twitter',
      uid: '999999999',
      info: {
        name: 'David Test',
        nickname: 'davidtest',
        email: @user.email_address  # Use existing user's email
      }
    })

    get "/auth/twitter/callback"
    
    assert_redirected_to new_session_url
    assert_equal "We found your account! Please sign in with your email to connect your Twitter account.", flash[:notice]
    
    # Should store OAuth data in session
    assert_equal 'twitter', session[:oauth_data]['provider']
    assert_equal '999999999', session[:oauth_data]['uid']
    assert_equal @user.email_address, session[:oauth_data]['info']['email']
  end

  test "oauth callback shows error for non-member trying to sign in" do
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new({
      provider: 'twitter',
      uid: '999999999',
      info: {
        name: 'Non Member',
        nickname: 'nonmember',
        email: 'nonmember@example.com'  # Email not in system
      }
    })

    get "/auth/twitter/callback"
    
    assert_redirected_to new_session_url
    assert_equal "No Small Bets account found. Please sign in with your membership email first, then connect your Twitter account from your profile.", flash[:alert]
  end

end
