class AddOriginalMessageIdAndDigestedToMessages < ActiveRecord::Migration[7.2]
  def change
    add_reference :messages, :original_message, null: true, foreign_key: { to_table: :messages }
    add_column :messages, :digested, :boolean, default: false, null: false
  end
end
