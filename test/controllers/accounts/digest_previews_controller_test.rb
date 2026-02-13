require "test_helper"

class Accounts::DigestPreviewsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    sign_in :david
    Rails.application.routes.default_url_options[:host] = "localhost:3000"
    ActionMailer::Base.default_url_options[:host] = "localhost:3000"
    ActionMailer::Base.delivery_method = :test
  end

  test "admin can send a test digest" do
    HomeFeed::Ranker.stubs(:top).returns(mock_cards(3))

    assert_emails 1 do
      post account_digest_preview_url, params: { email: users(:david).email_address }
    end

    assert_redirected_to edit_account_url
    assert_equal "Digest preview sent to #{users(:david).email_address}.", flash[:notice]
  end

  test "non-admin is forbidden" do
    sign_in :kevin

    post account_digest_preview_url, params: { email: users(:david).email_address }
    assert_response :forbidden
  end

  test "invalid email shows error flash" do
    post account_digest_preview_url, params: { email: "nobody@example.com" }

    assert_redirected_to edit_account_url
    assert_equal "No user found with that email.", flash[:alert]
  end

  test "not enough topics shows error flash" do
    HomeFeed::Ranker.stubs(:top).returns(mock_cards(1))

    post account_digest_preview_url, params: { email: users(:david).email_address }

    assert_redirected_to edit_account_url
    assert_match(/Only 1 topics found/, flash[:alert])
  end

  private

  def mock_cards(count)
    rooms = Room.limit(count).pluck(:id)
    rooms.map { |id| OpenStruct.new(room_id: id) }
  end
end
