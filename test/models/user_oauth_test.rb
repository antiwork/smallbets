require "test_helper"

class UserOauthTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
  end

  test "find_by_oauth returns user with matching provider and uid" do
    @user.update!(provider: 'twitter', uid: '123456789')
    
    found_user = User.find_by_oauth('twitter', '123456789')
    
    assert_equal @user, found_user
  end

  test "find_by_oauth returns nil when no match found" do
    found_user = User.find_by_oauth('twitter', '999999999')
    
    assert_nil found_user
  end

  test "find_by_oauth ignores inactive users" do
    @user.update!(provider: 'twitter', uid: '123456789', active: false)
    
    found_user = User.find_by_oauth('twitter', '123456789')
    
    assert_nil found_user
  end

  test "find_by_oauth ignores suspended users" do
    @user.update!(provider: 'twitter', uid: '123456789', suspended_at: Time.current)
    
    found_user = User.find_by_oauth('twitter', '123456789')
    
    assert_nil found_user
  end

  test "connect_oauth_account successfully connects new oauth account" do
    info = { 'name' => 'Test User', 'nickname' => 'testuser' }
    
    result = @user.connect_oauth_account('twitter', '123456789', info)
    
    assert result
    assert_equal 'twitter', @user.provider
    assert_equal '123456789', @user.uid
  end

  test "connect_oauth_account updates twitter username from oauth info" do
    @user.update!(twitter_username: nil)
    info = { 'nickname' => 'testuser' }
    
    @user.connect_oauth_account('twitter', '123456789', info)
    
    assert_equal 'testuser', @user.twitter_username
  end

  test "connect_oauth_account updates name from oauth info when user has default name" do
    @user.update!(name: User::DEFAULT_NAME)
    info = { 'name' => 'Real Name' }
    
    @user.connect_oauth_account('twitter', '123456789', info)
    
    assert_equal 'Real Name', @user.name
  end

  test "connect_oauth_account does not update name when user has custom name" do
    original_name = @user.name
    info = { 'name' => 'Different Name' }
    
    @user.connect_oauth_account('twitter', '123456789', info)
    
    assert_equal original_name, @user.name
  end

  test "connect_oauth_account fails when oauth account already connected to another user" do
    other_user = users(:jason)
    other_user.update!(provider: 'twitter', uid: '123456789')
    
    result = @user.connect_oauth_account('twitter', '123456789')
    
    refute result
    assert_nil @user.provider
    assert_nil @user.uid
  end

  test "connect_oauth_account allows user to reconnect their own oauth account" do
    @user.update!(provider: 'twitter', uid: '123456789')
    
    result = @user.connect_oauth_account('twitter', '123456789')
    
    assert result
    assert_equal 'twitter', @user.provider
    assert_equal '123456789', @user.uid
  end

  test "disconnect_oauth_account removes oauth connection" do
    @user.update!(provider: 'twitter', uid: '123456789')
    
    @user.disconnect_oauth_account
    
    assert_nil @user.provider
    assert_nil @user.uid
  end

  test "oauth_connected? returns true when oauth is connected" do
    @user.update!(provider: 'twitter', uid: '123456789')
    
    assert @user.oauth_connected?
  end

  test "oauth_connected? returns false when oauth is not connected" do
    refute @user.oauth_connected?
  end

  test "oauth_connected? returns false when only provider is set" do
    @user.update!(provider: 'twitter')
    
    refute @user.oauth_connected?
  end

  test "oauth_connected? returns false when only uid is set" do
    @user.update!(uid: '123456789')
    
    refute @user.oauth_connected?
  end

  test "oauth_provider_name returns formatted name for twitter" do
    @user.update!(provider: 'twitter')
    
    assert_equal 'X (Twitter)', @user.oauth_provider_name
  end

  test "oauth_provider_name returns titleized name for other providers" do
    @user.update!(provider: 'facebook')
    
    assert_equal 'Facebook', @user.oauth_provider_name
  end

  test "oauth_provider_name returns nil when no provider set" do
    assert_nil @user.oauth_provider_name
  end
end
