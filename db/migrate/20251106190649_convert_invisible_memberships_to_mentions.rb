class ConvertInvisibleMembershipsToMentions < ActiveRecord::Migration[8.0]
  def up
    # Convert all invisible memberships to mentions
    # This removes the legacy "hide room" feature in favor of the star system
    execute <<-SQL
      UPDATE memberships
      SET involvement = 'mentions'
      WHERE involvement = 'invisible'
    SQL
  end

  def down
    # No need to reverse this migration as invisible is being removed
    # If needed, admin can manually set memberships back to invisible
  end
end
