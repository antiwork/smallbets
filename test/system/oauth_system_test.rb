require "application_system_test_case"

class OauthSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:david)
  end

  test "should show Connect X button when user has no twitter_uid" do
    sign_in @user
    visit user_profile_path

    assert_text "Connect X"
    assert_no_text "Disconnect X"
  end

  test "should show Disconnect X button when user has twitter_uid" do
    @user.update!(twitter_uid: "12345")
    sign_in @user
    visit user_profile_path

    assert_text "Disconnect X"
    assert_no_text "Connect X"
  end

  test "should show Sign in with X button on login page" do
    visit new_session_path

    assert_text "Sign in with X"
    assert_selector "a[href='/auth/twitter2']"
  end

  test "should maintain twitter_url field functionality" do
    sign_in @user
    visit user_profile_path

    fill_in "user[twitter_url]", with: "https://x.com/david"
    click_button "✓"

    @user.reload
    assert_equal "https://x.com/david", @user.twitter_url
  end
end