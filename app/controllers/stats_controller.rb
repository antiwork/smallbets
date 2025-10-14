class StatsController < ApplicationController
  layout "application"
  include AccountsHelper

  def index
    # Get total counts
    counts = StatsService.total_counts
    @total_users = counts[:total_users]
    @total_messages = counts[:total_messages]
    @total_boosts = counts[:total_boosts]
    @total_posters = counts[:total_posters]
    @online_users = online_users_count

    db_path = ActiveRecord::Base.connection_db_config.configuration_hash[:database]
    @database_size = File.size(db_path) rescue 0

    # Get top rooms by message count
    @top_rooms = StatsService.top_rooms_by_message_count(10)

    # System metrics
    begin
      # CPU metrics
      os = RbConfig::CONFIG["host_os"]

      if os =~ /darwin/i
        # macOS
        @cpu_util = `top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d '%'`.to_f
        @cpu_cores = `sysctl -n hw.ncpu`.to_i
      elsif os =~ /linux/i
        # Linux (Ubuntu, etc.)
        cpu_info = `cat /proc/stat | grep '^cpu '`.split
        user = cpu_info[1].to_i
        nice = cpu_info[2].to_i
        system = cpu_info[3].to_i
        idle = cpu_info[4].to_i
        iowait = cpu_info[5].to_i
        irq = cpu_info[6].to_i
        softirq = cpu_info[7].to_i
        steal = cpu_info[8].to_i if cpu_info.size > 8
        steal ||= 0

        total = user + nice + system + idle + iowait + irq + softirq + steal
        used = total - idle - iowait
        @cpu_util = (used.to_f / total * 100).round(1)
        @cpu_cores = `nproc`.to_i
      end

      # Memory metrics
      if os =~ /darwin/i
        # macOS
        vm_stat = `vm_stat`
        matches = vm_stat.match(/Pages free:\s+(\d+)/)
        free_pages = matches ? matches[1].to_i : 0

        matches = vm_stat.match(/Pages inactive:\s+(\d+)/)
        inactive_pages = matches ? matches[1].to_i : 0

        matches = vm_stat.match(/Pages speculative:\s+(\d+)/)
        speculative_pages = matches ? matches[1].to_i : 0

        matches = vm_stat.match(/Pages wired down:\s+(\d+)/)
        wired_pages = matches ? matches[1].to_i : 0

        matches = vm_stat.match(/Pages active:\s+(\d+)/)
        active_pages = matches ? matches[1].to_i : 0

        # Calculate total memory
        total_memory = `sysctl -n hw.memsize`.to_i
        @total_memory_gb = (total_memory / 1024.0 / 1024.0).round(1)

        # Calculate available memory (free + inactive + speculative)
        page_size = 4096 # Default page size on macOS
        available_memory = (free_pages + inactive_pages + speculative_pages) * page_size
        @free_memory_percent = (available_memory.to_f / total_memory * 100).round(1)
        @memory_util_percent = 100 - @free_memory_percent
      elsif os =~ /linux/i
        # Linux (Ubuntu, etc.)
        mem_info = `cat /proc/meminfo`

        # Extract memory information
        total_kb = mem_info.match(/MemTotal:\s+(\d+)/)[1].to_i
        free_kb = mem_info.match(/MemFree:\s+(\d+)/)[1].to_i
        buffers_kb = mem_info.match(/Buffers:\s+(\d+)/)[1].to_i
        cached_kb = mem_info.match(/Cached:\s+(\d+)/)[1].to_i

        # Calculate total memory in GB
        @total_memory_gb = (total_kb / 1024.0 / 1024.0).round(1)

        # Calculate available memory (free + buffers + cached)
        available_kb = free_kb + buffers_kb + cached_kb
        @free_memory_percent = (available_kb.to_f / total_kb * 100).round(1)
        @memory_util_percent = 100 - @free_memory_percent
      end

      # Disk metrics
      if os =~ /darwin/i
        # macOS
        df_output = `df -h /`
        df_lines = df_output.split("\n")
        if df_lines.length > 1
          disk_info = df_lines[1].split
          @free_disk_percent = 100 - disk_info[4].to_i
          @disk_util_percent = disk_info[4].to_i
          @total_disk_gb = disk_info[1].gsub(/[^\d.]/, "").to_f
        end
      elsif os =~ /linux/i
        # Linux (Ubuntu, etc.)
        df_output = `df -h /`
        df_lines = df_output.split("\n")
        if df_lines.length > 1
          disk_info = df_lines[1].split
          # Format can be different on various Linux distributions
          # Typically: Filesystem Size Used Avail Use% Mounted on
          @total_disk_gb = disk_info[1].gsub(/[^\d.]/, "").to_f
          @disk_util_percent = disk_info[4].gsub("%", "").to_i
          @free_disk_percent = 100 - @disk_util_percent # Keep this for backward compatibility
        end
      end
    rescue => e
      # Log error but don't crash
      Rails.logger.error "Error getting system metrics: #{e.message}"
    end

    # Get daily and all-time stats
    @daily_stats = StatsService.daily_stats
    @all_time_stats = StatsService.all_time_daily_stats

    # Get top posters for different time periods
    @top_posters_today = StatsService.top_posters_today
    @top_posters_month = StatsService.top_posters_month
    @top_posters_year = StatsService.top_posters_year
    @top_posters_all_time = StatsService.top_posters_all_time

    # Get current user's stats for today if not in top 10
    if Current.user
      current_user_in_top_10_today = @top_posters_today.any? { |user| user.id == Current.user.id }

      if !current_user_in_top_10_today
        @current_user_today_stats = StatsService.user_stats_for_period(Current.user.id, :today)

        if @current_user_today_stats
          @current_user_today_rank = StatsService.calculate_user_rank(Current.user.id, :today)
          @total_active_users = @total_users # Already calculated above
        end
      end
    end

    # Get current user's stats for month if not in top 10
    if Current.user
      current_user_in_top_10_month = @top_posters_month.any? { |user| user.id == Current.user.id }

      if !current_user_in_top_10_month
        @current_user_month_stats = StatsService.user_stats_for_period(Current.user.id, :month)

        if @current_user_month_stats
          @current_user_month_rank = StatsService.calculate_user_rank(Current.user.id, :month)
          @total_active_users ||= @total_users # Already calculated above
        end
      end
    end

    # Get current user's stats for year if not in top 10
    if Current.user
      current_user_in_top_10_year = @top_posters_year.any? { |user| user.id == Current.user.id }

      if !current_user_in_top_10_year
        @current_user_year_stats = StatsService.user_stats_for_period(Current.user.id, :year)

        if @current_user_year_stats
          @current_user_year_rank = StatsService.calculate_user_rank(Current.user.id, :year)
          @total_active_users ||= @total_users # Already calculated above
        end
      end
    end

    # Get current user's stats for all time if not in top 10
    if Current.user
      current_user_in_top_10_all_time = @top_posters_all_time.any? { |user| user.id == Current.user.id }

      if !current_user_in_top_10_all_time
        @current_user_all_time_stats = StatsService.user_stats_for_period(Current.user.id, :all_time)

        if @current_user_all_time_stats
          @current_user_all_time_rank = StatsService.calculate_all_time_rank(Current.user.id)
          @total_active_users ||= @total_users # Already calculated above
        end
      end
    end

    # Get newest members
    @newest_members = StatsService.newest_members
    @blocked_members = StatsService.blocked_members
  end

  def today
    @page_title = "Daily Stats"

    # Get all days with messages (no time limit), using simple strftime
    all_days = Message.select("strftime('%Y-%m-%d', created_at) as date")
                  .group("date")
                  .order("date DESC")
                  .map(&:date)

    # Group days by month
    days_by_month = all_days.group_by do |day|
      date = Date.parse(day)
      "#{date.year}-#{date.month.to_s.rjust(2, '0')}"
    end

    # Sort months in descending order
    @sorted_months = days_by_month.keys.sort.reverse

    # Check for month parameter in either the URL path or query params
    month_param = params[:month]

    if month_param.present?
      # If a specific month is requested, only load that month's data
      @month = month_param
      if days_by_month[@month].present?
        @days = days_by_month[@month].sort.reverse

        # For each day, get the top 10 posters
        @daily_stats = {}
        @days.each do |day|
          @daily_stats[day] = StatsService.top_posters_for_day(day)
        end

        # Log for debugging
        Rails.logger.debug "Rendering month data for #{@month} with #{@days.size} days"

        respond_to do |format|
          format.html { render partial: "stats/month_data", locals: { month: @month, days: @days, daily_stats: @daily_stats } }
          format.turbo_stream { render partial: "stats/month_data", locals: { month: @month, days: @days, daily_stats: @daily_stats } }
        end
        nil
      end
    else
      # For initial page load, only load the first month
      @initial_month = @sorted_months.first
      @days = days_by_month[@initial_month].sort.reverse

      # For each day, get the top 10 posters
      @daily_stats = {}
      @days.each do |day|
        @daily_stats[day] = StatsService.top_posters_for_day(day)
      end

      # Store all months for the view to use
      @all_months = @sorted_months

      render "stats/today"
    end
  end

  def month
    @page_title = "Monthly Stats"

    # Get all months with messages
    @months = Message.select("strftime('%Y-%m', created_at) as month")
                    .group("month")
                    .order("month DESC")
                    .map(&:month)

    # For each month, get the top 10 posters
    @monthly_stats = {}
    @months.each do |month|
      @monthly_stats[month] = StatsService.top_posters_for_month(month)
    end

    render "stats/month"
  end

  def year
    @page_title = "Yearly Stats"

    # Get all years with messages
    @years = Message.select("strftime('%Y', created_at) as year")
                   .group("year")
                   .order("year DESC")
                   .map(&:year)

    # For each year, get the top 10 posters
    @yearly_stats = {}
    @years.each do |year|
      @yearly_stats[year] = StatsService.top_posters_for_year(year)
    end

    render "stats/year"
  end

  def all
    @page_title = "All-Time Stats"

    # Precompute all user ranks
    all_ranks = StatsService.precompute_all_time_ranks

    # Get users with at least one message and their ranks
    users_with_ranks = all_ranks.map do |user_id, rank|
      [ user_id, rank ]
    end

    # Filter out users with no messages by checking the rank
    # (lower ranks = more messages, so users with messages will have ranks <= total users with messages)
    total_users_with_messages = StatsService.all_users_with_messages.select { |u| u.message_count.to_i > 0 }.count
    users_with_messages = users_with_ranks.select { |user_id, rank| rank <= total_users_with_messages }

    # Sort by rank (ascending)
    sorted_user_ids = users_with_messages.sort_by { |user_id, rank| rank }.map(&:first)

    # Fetch the users in the correct order
    @all_time_stats = User.where(id: sorted_user_ids).includes(:avatar_attachment)
                          .index_by(&:id).slice(*sorted_user_ids).values

    # Add the precomputed ranks to the view
    @precomputed_ranks = all_ranks

    # Get total count for context
    @total_users_with_messages = users_with_messages.length
    @total_active_users = User.where(active: true, suspended_at: nil).count

    render "stats/all"
  end

  def rooms
    @page_title = "Room Stats"

    rooms_message_count_subquery = <<~SQL
      (
        SELECT COUNT(DISTINCT messages.id) FROM messages
        LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'
        LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id
        WHERE messages.active = true AND (messages.room_id = rooms.id OR parent_messages.room_id = rooms.id)
      ) AS message_count
    SQL

    # Get all open rooms ordered by message count
    @rooms = Room.select("rooms.*", rooms_message_count_subquery)
                 .where(type: "Rooms::Open")
                 .group("rooms.id")
                 .order("message_count DESC, rooms.created_at ASC")
                 .includes(:creator) # Include creator to avoid N+1 queries

    # For each room, find the top talker
    @top_talkers = {}
    @rooms.each do |room|
      top_talker = User.select("users.id, users.name, COUNT(DISTINCT messages.id) AS message_count")
                       .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true")
                       .joins("LEFT JOIN rooms threads ON messages.room_id = threads.id AND threads.type = 'Rooms::Thread'")
                       .joins("LEFT JOIN messages parent_messages ON threads.parent_message_id = parent_messages.id")
                       .where("messages.room_id = :room_id OR parent_messages.room_id = :room_id", room_id: room.id)
                       .where("users.active = true AND users.suspended_at IS NULL")
                       .group("users.id, users.name")
                       .order("message_count DESC")
                       .first

      @top_talkers[room.id] = top_talker if top_talker
    end

    render "stats/rooms"
  end

  def month_data
    # Get all days with messages for the specified month
    month_param = params[:month]

    unless month_param.present?
      render plain: "Month parameter is required", status: :bad_request
      return
    end

    # Get all days with messages
    all_days = Message.select("strftime('%Y-%m-%d', created_at) as date")
                .group("date")
                .order("date DESC")
                .map(&:date)

    # Filter days for the specified month
    days_in_month = all_days.select do |day|
      date = Date.parse(day)
      "#{date.year}-#{date.month.to_s.rjust(2, '0')}" == month_param
    end.sort.reverse

    if days_in_month.empty?
      render plain: "No data for month #{month_param}", status: :not_found
      return
    end

    # For each day, get the top 10 posters
    @daily_stats = {}
    days_in_month.each do |day|
      @daily_stats[day] = StatsService.top_posters_for_day(day)
    end

    # Log for debugging
    Rails.logger.debug "Rendering month data for #{month_param} with #{days_in_month.size} days"

    render partial: "stats/month_data", locals: { month: month_param, days: days_in_month, daily_stats: @daily_stats }
  end
end
