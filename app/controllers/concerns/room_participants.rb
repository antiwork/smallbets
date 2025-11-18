module RoomParticipants
  extend ActiveSupport::Concern

  private

  def participants_for_rooms(room_ids, limit: 4)
    return {} if room_ids.empty?

    last_activity = Message.active
                           .where(room_id: room_ids)
                           .group(:room_id, :creator_id)
                           .maximum(:created_at)

    grouped = Hash.new { |hash, key| hash[key] = [] }

    last_activity.each do |(room_id, creator_id), timestamp|
      grouped[room_id] << [creator_id, timestamp]
    end

    selected_user_ids = grouped.values.flat_map do |entries|
      entries.sort_by { |(_, ts)| -ts.to_i }.first(limit).map(&:first)
    end.uniq

    users_by_id = User.with_attached_avatar.where(id: selected_user_ids).index_by(&:id)

    grouped.transform_values do |entries|
      entries
        .sort_by { |(_, ts)| -ts.to_i }
        .first(limit)
        .filter_map { |user_id, _| users_by_id[user_id] }
    end
  end
end
