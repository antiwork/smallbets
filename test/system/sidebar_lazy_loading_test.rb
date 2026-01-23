require "application_system_test_case"

class SidebarLazyLoadingTest < ApplicationSystemTestCase
  setup do
    sign_in "jz@37signals.com"
  end

  test "involvement buttons load lazily on hover" do
    # Initially, sidebar shows placeholder icons (not interactive buttons)
    within ".rooms" do
      assert_selector ".involvement-placeholder", minimum: 1

      # Find a room item and hover over it
      room_item = first(".room-item")
      room_item.hover

      # After hover, the turbo frame should load the actual button
      within room_item do
        assert_selector "turbo-frame .btn", wait: 5
      end
    end
  end

  test "sidebar rooms display correctly on initial load" do
    # Verify rooms are visible in the sidebar
    within ".rooms" do
      assert_selector "[data-type='list_node']", minimum: 1
    end

    # Verify direct messages section is visible
    assert_selector ".directs", visible: true
  end
end
