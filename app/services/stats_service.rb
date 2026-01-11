class StatsService
  # Get top posters for today
  def self.top_posters_today(limit = 10)
    today = Time.now.utc.strftime("%Y-%m-%d")

    # Use the same direct query approach as in top_posters_for_day
    User.select("users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
        .where("strftime('%Y-%m-%d', messages.created_at) = ?", today)
        .where("users.active = true AND users.suspended_at IS NULL")
        .group("users.id, users.name, users.membership_started_at, users.created_at")
        .order("message_count DESC, joined_at ASC, users.id ASC")
        .limit(limit)
  end

  # Get top posters for this month
  def self.top_posters_month(limit = 10)
    current_month = Time.now.utc.strftime("%Y-%m")
    top_posters_for_month(current_month, limit)
  end

  # Get top posters for this year
  def self.top_posters_year(limit = 10)
    current_year = Time.now.utc.year.to_s
    top_posters_for_year(current_year, limit)
  end

  # Get top posters for all time
  def self.top_posters_all_time(limit = 10)
    User.select("users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .joins(messages: :room)
        .where("rooms.type != ? AND messages.active = true", "Rooms::Direct")
        .where("users.active = true AND users.suspended_at IS NULL")
        .group("users.id, users.name, users.membership_started_at, users.created_at")
        .order("message_count DESC, joined_at ASC, users.id ASC")
        .limit(limit)
  end

  # Get all users with at least one message (for all-time stats page)
  # Note: Despite the name, this now includes all users, even those with no messages
  def self.all_users_with_messages
    # Use the same query structure as precompute_all_time_ranks for consistency
    User.select("users.*, COALESCE(COUNT(CASE WHEN messages.id IS NOT NULL AND messages.active = true AND rooms.type != 'Rooms::Direct' THEN messages.id END), 0) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .joins("LEFT JOIN messages ON messages.creator_id = users.id")
        .joins("LEFT JOIN rooms ON messages.room_id = rooms.id")
        .where("users.active = true AND users.suspended_at IS NULL")
        .group("users.id")
        .order("message_count DESC, joined_at ASC, users.id ASC")
  end

  # Get user stats for a specific time period
  def self.user_stats_for_period(user_id, period = :all_time)
    user = User.find_by(id: user_id)
    return nil unless user

    case period
    when :today
      today_start = Time.now.utc.beginning_of_day
      today_end = today_start.end_of_day

      stats = User.select("users.id, users.name, COUNT(messages.id) AS message_count")
                 .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                        INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                 .where("messages.created_at >= ? AND messages.created_at <= ?", today_start, today_end)
                 .where("users.id = ?", user_id)
                 .group("users.id")
                 .first
    when :month
      current_month = Time.now.utc.strftime("%Y-%m")
      month_start = Time.new(Time.now.utc.year, Time.now.utc.month, 1, 0, 0, 0, "+00:00").beginning_of_month
      month_end = month_start.end_of_month

      stats = User.select("users.id, users.name, COUNT(messages.id) AS message_count")
                 .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                        INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                 .where("messages.created_at >= ? AND messages.created_at <= ?", month_start, month_end)
                 .where("users.id = ?", user_id)
                 .group("users.id")
                 .first
    when :year
      year_start = Time.now.utc.beginning_of_year
      year_end = year_start.end_of_year

      stats = User.select("users.id, users.name, COUNT(messages.id) AS message_count")
                 .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                        INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                 .where("messages.created_at >= ? AND messages.created_at <= ?", year_start, year_end)
                 .where("users.id = ?", user_id)
                 .group("users.id")
                 .first
    else # all_time
      stats = User.select("users.id, users.name, COALESCE(COUNT(messages.id), 0) AS message_count")
                 .joins("LEFT JOIN messages ON messages.creator_id = users.id AND messages.active = true
                        LEFT JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                 .where("users.id = ?", user_id)
                 .group("users.id")
                 .first
    end

    # If no stats found, create a default object with 0 messages
    if stats.nil?
      stats = User.select("users.id, users.name, 0 AS message_count")
                 .where("users.id = ?", user_id)
                 .first
    end

    stats
  end

  # Calculate user rank for a specific time period
  def self.calculate_user_rank(user_id, period = :all_time)
    # For all_time period, use the canonical ranking method
    return calculate_all_time_rank(user_id) if period == :all_time

    user = User.find_by(id: user_id)
    return nil unless user

    stats = user_stats_for_period(user_id, period)
    return nil unless stats

    # Get total number of active users for proper ranking context
    total_active_users = User.where(active: true, suspended_at: nil).count

    case period
    when :today
      today_start = Time.now.utc.beginning_of_day
      today_end = today_start.end_of_day

      # Count users with more messages using INNER JOIN like in top_posters_today
      users_with_more_messages = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                                          INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                    .where("messages.created_at >= ? AND messages.created_at <= ?", today_start, today_end)
                                    .where("users.active = true AND users.suspended_at IS NULL")
                                    .group("users.id")
                                    .having("COUNT(messages.id) > ?", stats.message_count.to_i)
                                    .count.size
    when :month
      month_start = Time.new(Time.now.utc.year, Time.now.utc.month, 1, 0, 0, 0, "+00:00").beginning_of_month
      month_end = month_start.end_of_month

      # Count users with more messages using INNER JOIN like in top_posters_month
      users_with_more_messages = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                                          INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                    .where("messages.created_at >= ? AND messages.created_at <= ?", month_start, month_end)
                                    .where("users.active = true AND users.suspended_at IS NULL")
                                    .group("users.id")
                                    .having("COUNT(messages.id) > ?", stats.message_count.to_i)
                                    .count.size
    when :year
      year_start = Time.now.utc.beginning_of_year
      year_end = year_start.end_of_year

      # Count users with more messages using INNER JOIN like in top_posters_year
      users_with_more_messages = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                                          INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                    .where("messages.created_at >= ? AND messages.created_at <= ?", year_start, year_end)
                                    .where("users.active = true AND users.suspended_at IS NULL")
                                    .group("users.id")
                                    .having("COUNT(messages.id) > ?", stats.message_count.to_i)
                                    .count.size
    else # all_time
      # Count users with more messages
      users_with_more_messages = User.joins(messages: :room)
                                    .where("rooms.type != ? AND messages.active = true", "Rooms::Direct")
                                    .where("users.active = true AND users.suspended_at IS NULL")
                                    .group("users.id")
                                    .having("COUNT(messages.id) > ?", stats.message_count.to_i)
                                    .count.size
    end

    # Count users with same number of messages but earlier join date
    if stats.message_count.to_i > 0
      case period
      when :today
        today_start = Time.now.utc.beginning_of_day
        today_end = today_start.end_of_day

        users_with_same_messages_earlier_join = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                                                        INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                                  .where("messages.created_at >= ? AND messages.created_at <= ?", today_start, today_end)
                                                  .where("users.active = true AND users.suspended_at IS NULL")
                                                  .group("users.id")
                                                  .having("COUNT(messages.id) = ?", stats.message_count.to_i)
                                                  .where("COALESCE(users.membership_started_at, users.created_at) < ?",
                                                         user.membership_started_at || user.created_at)
                                                  .count.size
      when :month
        time_start = Time.new(Time.now.utc.year, Time.now.utc.month, 1, 0, 0, 0, "+00:00").beginning_of_month
        time_end = time_start.end_of_month

        users_with_same_messages_earlier_join = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                                                        INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                                  .where("messages.created_at >= ? AND messages.created_at <= ?", time_start, time_end)
                                                  .where("users.active = true AND users.suspended_at IS NULL")
                                                  .group("users.id")
                                                  .having("COUNT(messages.id) = ?", stats.message_count.to_i)
                                                  .where("COALESCE(users.membership_started_at, users.created_at) < ?",
                                                         user.membership_started_at || user.created_at)
                                                  .count.size
      when :year
        year_start = Time.now.utc.beginning_of_year
        year_end = year_start.end_of_year

        users_with_same_messages_earlier_join = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                                                        INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
                                                  .where("messages.created_at >= ? AND messages.created_at <= ?", year_start, year_end)
                                                  .where("users.active = true AND users.suspended_at IS NULL")
                                                  .group("users.id")
                                                  .having("COUNT(messages.id) = ?", stats.message_count.to_i)
                                                  .where("COALESCE(users.membership_started_at, users.created_at) < ?",
                                                         user.membership_started_at || user.created_at)
                                                  .count.size
      else # all_time
        users_with_same_messages_earlier_join = User.joins(messages: :room)
                                                  .where("rooms.type != ? AND messages.active = true", "Rooms::Direct")
                                                  .where("users.active = true AND users.suspended_at IS NULL")
                                                  .group("users.id")
                                                  .having("COUNT(messages.id) = ?", stats.message_count.to_i)
                                                  .where("COALESCE(users.membership_started_at, users.created_at) < ?",
                                                         user.membership_started_at || user.created_at)
                                                  .count.size
      end
    else
      # For users with 0 messages, count users with earlier join date
      users_with_same_messages_earlier_join = User.where("COALESCE(membership_started_at, created_at) < ?",
                                                      user.membership_started_at || user.created_at)
                                              .where("active = true AND suspended_at IS NULL")
                                              .count
    end

    rank = users_with_more_messages + users_with_same_messages_earlier_join + 1

    # Sanity check: rank should never exceed total active users
    [ rank, total_active_users ].min
  end

  # Get daily stats for the last 7 days
  def self.daily_stats(limit = 7)
    # Use strftime directly with the created_at column
    Message.select("strftime('%Y-%m-%d', created_at) as date, count(*) as count")
          .group("date")
          .order("date DESC")
          .limit(limit)
  end

  # Get all-time daily stats
  def self.all_time_daily_stats
    # Use strftime directly with the created_at column
    Message.select("strftime('%Y-%m-%d', created_at) as date, count(*) as count")
          .group("date")
          .order("date ASC")
  end

  # Get top posters for a specific day
  def self.top_posters_for_day(day, limit = 10)
    # Explicitly parse the date in UTC timezone
    day_start = Time.parse(day + " UTC").beginning_of_day
    day_end = day_start.end_of_day

    # Use a more direct query with explicit date formatting to match SQLite's format
    day_formatted = day_start.strftime("%Y-%m-%d")

    User.select("users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
        .where("strftime('%Y-%m-%d', messages.created_at) = ?", day_formatted)
        .where("users.active = true AND users.suspended_at IS NULL")
        .group("users.id, users.name, users.membership_started_at, users.created_at")
        .order("message_count DESC, joined_at ASC, users.id ASC")
        .limit(limit)
  end

  # Get top posters for a specific month
  def self.top_posters_for_month(month, limit = 10)
    year, month_num = month.split("-")
    # Explicitly use UTC timezone
    month_start = Time.new(year.to_i, month_num.to_i, 1, 0, 0, 0, "+00:00").beginning_of_month
    month_end = month_start.end_of_month

    User.select("users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .joins(messages: :room)
        .where("rooms.type != ? AND messages.created_at >= ? AND messages.created_at <= ? AND messages.active = true",
              "Rooms::Direct", month_start, month_end)
        .where("users.active = true AND users.suspended_at IS NULL")
        .group("users.id, users.name, users.membership_started_at, users.created_at")
        .order("message_count DESC, joined_at ASC, users.id ASC")
        .limit(limit)
  end

  # Get top posters for a specific year
  def self.top_posters_for_year(year, limit = 10)
    # Explicitly use UTC timezone
    year_start = Time.new(year.to_i, 1, 1, 0, 0, 0, "+00:00").beginning_of_year
    year_end = year_start.end_of_year

    User.select("users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .joins(messages: :room)
        .where("rooms.type != ? AND messages.created_at >= ? AND messages.created_at <= ? AND messages.active = true",
              "Rooms::Direct", year_start, year_end)
        .where("users.active = true AND users.suspended_at IS NULL")
        .group("users.id, users.name, users.membership_started_at, users.created_at")
        .order("message_count DESC, joined_at ASC, users.id ASC")
        .limit(limit)
  end

  # Get newest members
  def self.newest_members(limit = 10)
    User.select("users.*, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .where(active: true)
        .where(suspended_at: nil)
        .order("joined_at DESC")
        .limit(limit)
  end

  def self.blocked_members(limit = 10)
    User.active
        .non_suspended
        .joins(:blocks_received)
        .group("users.id")
        .select("users.*, COUNT(blocks.id) AS blocks_count")
        .order("blocks_count DESC")
        .limit(limit)
  end

  # Get total counts for the stats page
  def self.total_counts
    Rails.cache.fetch("stats/total_counts", expires_in: 5.minutes) do
      {
        total_users: User.where(active: true, suspended_at: nil).count,
        total_messages: Message.count,
        total_threads: Room.active
                           .where(type: "Rooms::Thread")
                           .joins(:messages)
                           .where("messages.active = ?", true)
                           .distinct.count,
        total_boosts: Boost.count,
        total_posters: User.active.joins(messages: :room)
                           .where("rooms.type != ?", "Rooms::Direct")
                           .where("messages.active = ?", true)
                           .distinct.count
      }
    end
  end

  # Get top rooms by message count
  def self.top_rooms_by_message_count(limit = 10)
    Rails.cache.fetch("stats/top_rooms/#{limit}", expires_in: 10.minutes) do
      rooms_message_count_subquery = <<~SQL
        (
          SELECT COUNT(DISTINCT messages.id) FROM messages
          LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'
          LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id
          WHERE messages.active = true AND (messages.room_id = rooms.id OR parent_messages.room_id = rooms.id)
        ) AS message_count
      SQL

      Room.select("rooms.*", rooms_message_count_subquery)
          .where(type: "Rooms::Open")
          .group("rooms.id")
          .order("message_count DESC, rooms.created_at ASC")
          .limit(limit)
          .to_a
    end
  end

  # Precompute all user ranks for the all-time stats page
  # Returns a hash mapping user_id to rank
  # Results are cached using Rails.cache
  def self.precompute_all_time_ranks
    Rails.cache.fetch("stats/all_time_ranks", expires_in: 1.hour) do
      sql = <<~SQL
        WITH user_stats AS (
          SELECT
            users.id,
            COALESCE(COUNT(CASE WHEN messages.id IS NOT NULL AND messages.active = true AND rooms.type != 'Rooms::Direct' THEN messages.id END), 0) AS message_count,
            COALESCE(users.membership_started_at, users.created_at) as joined_at
          FROM users
          LEFT JOIN messages ON messages.creator_id = users.id
          LEFT JOIN rooms ON messages.room_id = rooms.id
          WHERE users.active = true AND users.suspended_at IS NULL
          GROUP BY users.id, users.membership_started_at, users.created_at
        )
        SELECT
          id,
          RANK() OVER (ORDER BY message_count DESC, joined_at ASC, id ASC) as rank
        FROM user_stats
      SQL

      ranks = {}
      ActiveRecord::Base.connection.execute(sql).each do |row|
        ranks[row["id"].to_i] = row["rank"]
      end
      ranks
    end
  end

  # Calculate a user's rank in the all-time leaderboard
  def self.calculate_all_time_rank(user_id)
    user = User.find_by(id: user_id)
    return nil unless user

    precompute_all_time_ranks[user_id]
  end

  # Clear the cached all-time ranks
  def self.clear_all_time_ranks_cache
    Rails.cache.delete("stats/all_time_ranks")
  end

  # ============================================
  # Room-scoped stats methods
  # ============================================

  # Count messages in a room including messages in threads
  def self.room_messages_count(room)
    Rails.cache.fetch("stats/room/#{room.id}/messages_count", expires_in: 5.minutes) do
      Message.joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
             .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
             .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
             .active.distinct.count
    end
  end

  # Get top talkers for a specific room
  def self.room_top_talkers(room, limit = 10)
    Rails.cache.fetch("stats/room/#{room.id}/top_talkers/#{limit}", expires_in: 5.minutes) do
      User.select("users.id, users.name, COUNT(DISTINCT messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
          .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true")
          .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
          .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
          .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
          .where("users.active = true AND users.suspended_at IS NULL")
          .group("users.id, users.name, users.membership_started_at, users.created_at")
          .order("message_count DESC, joined_at ASC, users.id ASC")
          .limit(limit)
          .map { |u| { id: u.id, name: u.name, message_count: u.message_count } }
    end
  end

  # Get user stats for a specific room
  def self.room_user_stats(room, user)
    return nil unless user

    User.select("users.id, users.name, COUNT(DISTINCT messages.id) AS message_count")
        .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true")
        .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
        .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
        .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
        .where("users.id = ?", user.id)
        .group("users.id")
        .first
  end

  # Calculate user rank in a specific room
  def self.room_user_rank(room, user)
    return nil unless user

    Rails.cache.fetch("stats/room/#{room.id}/user/#{user.id}/rank", expires_in: 2.minutes) do
      stats = room_user_stats(room, user)
      next nil unless stats

      users_with_more_messages = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true")
                                     .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
                                     .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
                                     .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
                                     .where("users.active = true AND users.suspended_at IS NULL")
                                     .group("users.id")
                                     .having("COUNT(DISTINCT messages.id) > ?", stats.message_count.to_i)
                                     .count.size

      if stats.message_count.to_i > 0
        users_with_same_messages_earlier_join = User.joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true")
                                                    .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
                                                    .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
                                                    .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
                                                    .where("users.active = true AND users.suspended_at IS NULL")
                                                    .group("users.id")
                                                    .having("COUNT(DISTINCT messages.id) = ?", stats.message_count.to_i)
                                                    .where("COALESCE(users.membership_started_at, users.created_at) < ?",
                                                           user.membership_started_at || user.created_at)
                                                    .count.size
      else
        users_with_same_messages_earlier_join = User.where("COALESCE(membership_started_at, created_at) < ?",
                                                           user.membership_started_at || user.created_at)
                                                    .where("active = true AND suspended_at IS NULL")
                                                    .count
      end

      users_with_more_messages + users_with_same_messages_earlier_join + 1
    end
  end
end
