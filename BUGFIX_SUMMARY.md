# Bug Fix Summary: Issue #76 - Unstarring Room Removes It From All Rooms

## Problem
When clicking the ⭐ icon to unstar a room from within the actual room view, it would remove the room from both "My Rooms" AND "All Rooms". This was incorrect behavior - unstarring should only remove the room from "My Rooms", not from "All Rooms".

## Root Cause
The application had a legacy "hide rooms" feature from Campfire (the original codebase) that used an `invisible` involvement state. When clicking the star icon:

- **From the sidebar**: Cycled between `mentions` ↔ `everything` (correct ✅)
- **From room view**: Cycled between `mentions` → `everything` → `invisible` → `mentions` (bug ❌)

When a membership was set to `invisible`, the backend's `scope :visible` filtered it out, causing the room to disappear from both sidebar sections.

## Solution
Removed the `invisible` state from the involvement cycling for shared rooms, making both sidebar and room view use the same 2-state cycle: `mentions` ↔ `everything`.

## Files Changed

### 1. `app/helpers/rooms/involvements_helper.rb`
**Changes:**
- Updated `SHARED_INVOLVEMENT_ORDER` from `%w[ mentions everything invisible ]` to `%w[ mentions everything ]`
- Removed `"invisible" => "Room hidden from sidebar"` from `HUMANIZE_INVOLVEMENT` hash

**Impact:** This ensures that clicking the star icon from anywhere (sidebar or room view) will only cycle between `mentions` (unstarred, in "All Rooms") and `everything` (starred, in "My Rooms").

### 2. `app/controllers/rooms/involvements_controller.rb`
**Changes:**
- Replaced `add_or_remove_rooms_in_sidebar` method body with a comment explaining it's no longer needed
- Removed the case logic that broadcast room removal/addition when involvement changed to/from `invisible`

**Impact:** Rooms will never be removed from the sidebar entirely - they'll always appear in either "My Rooms" or "All Rooms".

### 3. `db/migrate/20251106190649_convert_invisible_memberships_to_mentions.rb` (NEW)
**Changes:**
- Created migration to convert all existing `invisible` memberships to `mentions`
- This ensures any rooms that were previously hidden will now appear in "All Rooms"

**Impact:** Cleans up existing data so no rooms are currently in the invisible state.

### 4. `app/models/rooms/thread.rb`
**Changes:**
- Updated `default_involvement` for non-creators from `"invisible"` to `"mentions"`

**Impact:** Thread rooms will now default to `mentions` instead of `invisible`. (Note: Thread rooms are never shown in the sidebar anyway due to `.without_thread_rooms` scope, so this is primarily for consistency.)

### 5. `test/controllers/rooms/involvements_controller_test.rb`
**Changes:**
- Replaced test "update involvement sends turbo update when becoming visible and when going invisible"
- New test: "updating involvement does not send turbo update when changing between visible states"
- Tests now verify cycling between `mentions` and `everything` instead of including `invisible`

**Impact:** Tests now reflect the correct behavior without the invisible state.

### 6. `test/models/room/push_test.rb`
**Changes:**
- Removed test "does not notify for invisible rooms"
- Updated test "destroys invalid subscriptions" to not use `invisible` involvement

**Impact:** Tests no longer reference the removed invisible feature.

## Behavior After Fix

### Starring/Unstarring from Sidebar
1. Click ⭐ on unstarred room → Room moves to "My Rooms" ✅
2. Click ⭐ on starred room → Room moves to "All Rooms" ✅

### Starring/Unstarring from Room View
1. Click ⭐ when unstarred (mentions) → Room is starred (everything) and appears in "My Rooms" ✅
2. Click ⭐ when starred (everything) → Room is unstarred (mentions) and stays in "All Rooms" ✅

**Key improvement:** Rooms never disappear from the sidebar completely!

## Database Changes
The `memberships.involvement` enum still includes `invisible` for backward compatibility, but it's no longer accessible through the UI. The migration converts all existing invisible memberships to mentions.

## Technical Notes

### Why Keep `invisible` in the Enum?
The `involvement` enum in `app/models/membership.rb:55` still includes `invisible` to maintain backward compatibility with existing database records. However, since we:
1. Converted all existing invisible memberships to mentions (via migration)
2. Removed it from all involvement cycling logic
3. Users can no longer set memberships to invisible through the UI

The invisible state effectively becomes "deprecated but not removed" to avoid database migration complexity.

### Scopes That Still Reference `invisible`
- `scope :visible, -> { where.not(involvement: :invisible) }` in `membership.rb:79`

This scope remains unchanged and continues to work correctly - it ensures that if any invisible memberships somehow exist, they won't appear in the sidebar.

## Testing
To test this fix:
1. Run the migration: `bundle exec rails db:migrate`
2. Run tests: `bundle exec rails test`
3. Manual testing:
   - Navigate to a room view
   - Click the star icon multiple times
   - Verify the room cycles between "My Rooms" (starred) and "All Rooms" (unstarred)
   - Verify the room never disappears completely

## Credits
Fix for: https://github.com/antiwork/smallbets/issues/76
Bounty: $100
