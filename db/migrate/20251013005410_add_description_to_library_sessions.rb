class AddDescriptionToLibrarySessions < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:library_sessions, :description)
      add_column :library_sessions, :description, :text
    end

    # Backfill existing rows with a generic placeholder to satisfy NOT NULL
    execute <<~SQL
      UPDATE library_sessions
      SET description = 'Session description to be added'
      WHERE description IS NULL;
    SQL

    change_column_null :library_sessions, :description, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "description may pre-exist; not removing"
  end
end


