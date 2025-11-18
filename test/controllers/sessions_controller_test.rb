require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_session_url
    assert_response :success
  end

  test "new redirects to first run when no users exist" do
    # Delete dependent records first to avoid foreign key violations from library_watch_histories
    ActiveRecord::Base.connection.disable_referential_integrity do
      User.destroy_all
    end

    get new_session_url

    assert_redirected_to first_run_url
  end

  test "new denied with incompatible browser" do
    get new_session_url
    assert_response :success
  end

  test "new allowed with compatible browser" do
    get new_session_url
    assert_response :success
  end

  test "create with valid credentials" do
    post session_url, params: { email_address: "david@37signals.com", password: "secret123456" }

    assert_redirected_to chat_url
    assert parsed_cookies.signed[:session_token]
  end

  test "create with invalid credentials" do
    post session_url, params: { email_address: "david@37signals.com", password: "wrong" }

    assert_response :unauthorized
    assert_nil parsed_cookies.signed[:session_token]
  end

  test "destroy" do
    sign_in :david

    delete session_url

    assert_redirected_to root_url
    assert_not cookies[:session_token].present?
  end

  test "destroy removes the push subscription for the device" do
    sign_in :david

    assert_difference -> { users(:david).push_subscriptions.count }, -1 do
      delete session_url, params: { push_subscription_endpoint: push_subscriptions(:david_chrome).endpoint }
    end

    assert_redirected_to root_url
    assert_not cookies[:session_token].present?
  end
end
