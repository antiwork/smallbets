class CreateEmailDigestEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :email_digest_entries do |t|
      t.references :room, null: false, foreign_key: true
      t.date :digest_date, null: false
      t.integer :position, null: false

      t.datetime :created_at, null: false
    end

    add_index :email_digest_entries, :digest_date
    add_index :email_digest_entries, [:room_id, :digest_date], unique: true

    add_column :accounts, :email_digest_enabled, :boolean, default: true, null: false
  end
end
