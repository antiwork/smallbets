class AddMentionsEveryoneToMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :messages, :mentions_everyone, :boolean, default: false, null: false
    add_index :messages, [:room_id, :mentions_everyone], where: "mentions_everyone = true"
  end
end
