class AddPreviewMessageIdToFeedCards < ActiveRecord::Migration[7.2]
  def change
    add_reference :feed_cards, :preview_message, null: true, foreign_key: { to_table: :messages }
  end
end
