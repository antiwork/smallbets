require "test_helper"

class UserOauthTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
  end

  test "should validate twitter_uid uniqueness" do
    @user.update!(twitter_uid: "12345")
    
    duplicate_user = users(:jason)
    duplicate_user.twitter_uid = "12345"
    
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:twitter_uid], "has already been taken"
  end

  test "should allow nil twitter_uid" do
    @user.twitter_uid = nil
    assert @user.valid?
  end

  test "should allow multiple users with nil twitter_uid" do
    users(:david).update!(twitter_uid: nil)
    users(:jason).update!(twitter_uid: nil)
    
    assert users(:david).valid?
    assert users(:jason).valid?
  end

  test "should save twitter_uid successfully" do
    @user.update!(twitter_uid: "twitter_12345")
    @user.reload
    
    assert_equal "twitter_12345", @user.twitter_uid
  end
end