require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "user does not prevent very long passwords" do
    users(:david).update(password: "secret" * 50)
    assert users(:david).valid?
  end

  test "creating users grants membership to the open rooms" do
    assert_difference -> { Membership.count }, +Rooms::Open.count do
      create_new_user
    end
  end

  test "deactivating a user deletes push subscriptions, searches, memberships for non-direct rooms, and changes their email address" do
    assert_difference -> { Membership.active.count }, -users(:david).memberships.without_direct_rooms.count do
    assert_difference -> { Push::Subscription.count }, -users(:david).push_subscriptions.count do
    assert_difference -> { Search.count }, -users(:david).searches.count do
      SecureRandom.stubs(:uuid).returns("2e7de450-cf04-4fa8-9b02-ff5ab2d733e7")
      users(:david).deactivate
      assert_equal "david-deactivated-2e7de450-cf04-4fa8-9b02-ff5ab2d733e7@37signals.com", users(:david).reload.email_address
    end
    end
    end
  end

  test "deactivating a user deletes their sessions" do
    assert_changes -> { users(:david).sessions.count }, from: 1, to: 0 do
      users(:david).deactivate
    end
  end

  test "active_non_suspended scope returns only active and non-suspended users" do
    active_user = users(:david)
    active_user.update!(active: true, suspended_at: nil)

    inactive_user = create_new_user
    inactive_user.update!(active: false, suspended_at: nil)

    suspended_user = User.create!(name: "Suspended", email_address: "suspended@example.com", password: "secret123456")
    suspended_user.update!(active: true, suspended_at: Time.current)

    inactive_suspended_user = User.create!(name: "InactiveSuspended", email_address: "inactive_suspended@example.com", password: "secret123456")
    inactive_suspended_user.update!(active: false, suspended_at: Time.current)

    results = User.active_non_suspended

    assert_includes results, active_user
    refute_includes results, inactive_user
    refute_includes results, suspended_user
    refute_includes results, inactive_suspended_user
  end

  private
    def create_new_user
      User.create!(name: "User", email_address: "user@example.com", password: "secret123456")
    end
end
