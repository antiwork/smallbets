class RenameDigestToFeed < ActiveRecord::Migration[7.2]
  def up
    # Rename digested column to in_feed in messages table
    rename_column :messages, :digested, :in_feed
    
    # Update feed_cards type values from "digest" to "automated"
    execute <<-SQL
      UPDATE feed_cards SET type = 'automated' WHERE type = 'digest';
    SQL
  end

  def down
    # Revert feed_cards type values from "automated" to "digest"
    execute <<-SQL
      UPDATE feed_cards SET type = 'digest' WHERE type = 'automated';
    SQL
    
    # Rename in_feed column back to digested in messages table
    rename_column :messages, :in_feed, :digested
  end
end
