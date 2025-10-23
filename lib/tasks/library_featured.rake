namespace :library do
  desc "Set featured videos for the hero carousel (idempotent)"
  task set_featured_hero: :environment do
    ids = [53, 1, 2, 3, 17, 4, 7, 16, 21, 5]

    puts "Resetting all featured statuses and positions..."

    ActiveRecord::Base.transaction do
      # Reset all featured flags and positions
      LibrarySession.update_all(featured: false, featured_position: 0)

      # Set the provided IDs in the specified order
      missing = []
      updated_count = 0

      ids.each_with_index do |session_id, idx|
        affected = LibrarySession.where(id: session_id).update_all(featured: true, featured_position: idx)
        if affected.zero?
          missing << session_id
        else
          updated_count += affected
        end
      end

      puts "\n✓ Set #{updated_count} featured sessions in hero order"
      puts "⚠ Missing sessions (not found): #{missing.join(", ")}" unless missing.empty?
    end
  end
end


