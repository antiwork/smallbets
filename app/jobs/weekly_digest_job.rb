class WeeklyDigestJob < ApplicationJob
  MIN_TOPICS = 3
  MAX_TOPICS = 10

  def perform(since: 1.week.ago)
    @since = since

    unless Current.account&.email_digest_enabled?
      log "Email digest is disabled. Skipping."
      return
    end

    rooms = top_rooms_from_last_week
    if rooms.length < MIN_TOPICS
      log "Only #{rooms.length} topics found (minimum: #{MIN_TOPICS}). Skipping."
      return
    end

    record_digest_entries(rooms)
    send_to_subscribers(rooms)

    log "Done. Sent digest with #{rooms.length} topics."
  end

  private

  def top_rooms_from_last_week
    excluded_room_ids = EmailDigestEntry.previously_sent_room_ids
    cards = HomeFeed::Ranker.top(limit: MAX_TOPICS, since: @since, exclude_room_ids: excluded_room_ids)
    room_ids = cards.map(&:room_id)

    Room.includes(:source_room, :automated_feed_card).where(id: room_ids).index_by(&:id)
        .then { |rooms_by_id| room_ids.filter_map { |id| rooms_by_id[id] } }
  end

  def record_digest_entries(rooms)
    digest_date = Date.current
    entries = rooms.each_with_index.map do |room, index|
      { room_id: room.id, digest_date: digest_date, position: index + 1, created_at: Time.current }
    end

    EmailDigestEntry.insert_all(entries)
  end

  def send_to_subscribers(rooms)
    User.active.non_suspended.subscribed("weekly_digest").find_each do |user|
      DigestMailer.weekly(user, rooms).deliver_now
      log "Sent digest.", user
    rescue => e
      log "Failed to send digest: #{e.message}", user
    end
  end

  def log(message, user = nil)
    Rails.logger.info "[WeeklyDigestJob]#{"[#{user.id}]" if user.present?} #{message}"
  end
end
