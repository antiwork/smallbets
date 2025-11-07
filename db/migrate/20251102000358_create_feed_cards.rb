class CreateFeedCards < ActiveRecord::Migration[7.2]
  def change
    create_table :feed_cards do |t|
      t.references :room, null: false, foreign_key: true
      t.string :title, null: false
      t.text :summary
      t.string :type, null: false
      t.references :promoted_by_user, null: true, foreign_key: { to_table: :users }
      t.string :message_fingerprint

      t.timestamps
    end

    add_index :feed_cards, :created_at
    add_index :feed_cards, :type
  end
end
