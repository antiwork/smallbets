class AddIndexOnMessagesActiveColumn < ActiveRecord::Migration[7.2]
  def change
    add_index :messages, :active
  end
end
