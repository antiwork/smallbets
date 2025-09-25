require "application_system_test_case"

class OauthIntegrationTest < ApplicationSystemTestCase
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

  test "user can connect X account from profile page" do
    sign_in_as @user
    
    # Mock successful Twitter OAuth
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new({
      provider: 'twitter',
      uid: '123456789',
      info: {
        name: 'Test User',
        nickname: 'testuser',
        image: 'http://example.com/avatar.jpg'
      }
    })

    visit user_profile_path
    
    # Should see connect button
    assert_text "Connect your X account for easier sign-in"
    assert_link "Connect X Account"
    
    # Click connect button
    click_link "Connect X Account"
    
    # Should be redirected back to profile with success message
    assert_current_path user_profile_path
    assert_text "Successfully connected your Twitter account!"
    
    # Should now show connected status
    assert_text "Connected to X (Twitter)"
    assert_text "(@testuser)"
    assert_button "Disconnect"
    
    # Verify database was updated
    @user.reload
    assert_equal 'twitter', @user.provider
    assert_equal '123456789', @user.uid
  end

  test "user can disconnect X account from profile page" do
    # Setup user with connected OAuth account
    @user.update!(provider: 'twitter', uid: '123456789', twitter_username: 'testuser')
    sign_in_as @user
    
    visit user_profile_path
    
    # Should see connected status
    assert_text "Connected to X (Twitter)"
    assert_text "(@testuser)"
    assert_button "Disconnect"
    
    # Accept confirmation dialog and click disconnect
    accept_confirm do
      click_button "Disconnect"
    end
    
    # Should be redirected back to profile with success message
    assert_current_path user_profile_path
    assert_text "Successfully disconnected your X (Twitter) account."
    
    # Should now show connect button again
    assert_text "Connect your X account for easier sign-in"
    assert_link "Connect X Account"
    
    # Verify database was updated
    @user.reload
    assert_nil @user.provider
    assert_nil @user.uid
  end

  test "user cannot connect account already linked to another user" do
    # Setup another user with the OAuth account
    other_user = users(:jason)
    other_user.update!(provider: 'twitter', uid: '123456789')
    
    sign_in_as @user
    
    # Mock OAuth response with same UID
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new({
      provider: 'twitter',
      uid: '123456789',
      info: { name: 'Test User' }
    })

    visit user_profile_path
    click_link "Connect X Account"
    
    # Should show error message
    assert_current_path user_profile_path
    assert_text "Failed to connect your Twitter account. It may already be connected to another user."
    
    # Should still show connect button
    assert_text "Connect your X account for easier sign-in"
    assert_link "Connect X Account"
    
    # Verify user's account was not connected
    @user.reload
    assert_nil @user.provider
    assert_nil @user.uid
  end

  test "oauth failure shows error message" do
    sign_in_as @user
    
    # Mock OAuth failure
    OmniAuth.config.mock_auth[:twitter] = :invalid_credentials
    
    visit user_profile_path
    click_link "Connect X Account"
    
    # Should be redirected to sign in page with error
    assert_current_path new_session_path
    assert_text "Authentication failed. Please try again."
  end

  private

  def sign_in_as(user)
    session = user.sessions.create!(
      user_agent: "TestAgent", 
      ip_address: "127.0.0.1"
    )
    
    # Set the session cookie
    page.driver.browser.set_cookie("session_token=#{session.token}; path=/; domain=#{Capybara.app_host || 'www.example.com'}")
    
    # Also set the session user_id for Rails session
    visit root_path # This will trigger the authentication check
  end
end
