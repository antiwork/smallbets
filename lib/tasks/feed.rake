namespace :feed do
  desc "Run automated feed scan manually"
  task scan: :environment do
    puts "Starting automated feed scan..."
    
    result = AutomatedFeed::ScheduledScanJob.new.perform
    
    puts "Scan complete!"
  end

  desc "Debug scan - shows detailed information about what's happening"
  task debug_scan: :environment do
    puts "=" * 80
    puts "AUTOMATED FEED SCAN DEBUG"
    puts "=" * 80
    
    config = AutomatedFeed.config
    puts "\nConfiguration:"
    puts "  Enabled: #{config.enable_automated_scans}"
    puts "  Lookback hours: #{config.lookback_hours}"
    puts "  Max conversations: #{config.max_conversations_per_scan}"
    puts "  AI model: #{config.ai_model}"
    
    unless config.enable_automated_scans
      puts "\n⚠️  Scanner is disabled! Set AUTOMATED_FEED_ENABLED=true"
      exit
    end
    
    lookback_start = config.lookback_hours.hours.ago
    puts "\nTime window:"
    puts "  From: #{lookback_start.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  To:   #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    
    puts "\nMessage counts:"
    total_messages = Message.active.count
    recent_messages = Message.active.where("created_at >= ?", lookback_start).count
    in_feed_messages = Message.in_feed.count
    not_in_feed_recent = Message.active.not_in_feed.where("created_at >= ?", lookback_start).count
    conversation_rooms = Room.where.not(source_room_id: nil).count
    
    puts "  Total active messages: #{total_messages}"
    puts "  Recent messages (last #{config.lookback_hours}h): #{recent_messages}"
    puts "  Already in feed: #{in_feed_messages}"
    puts "  Not in feed + recent: #{not_in_feed_recent}"
    puts "  Conversation rooms (excluded): #{conversation_rooms}"
    
    eligible_messages = Message.active
                                .not_in_feed
                                .where.not(room_id: Room.where.not(source_room_id: nil).select(:id))
                                .between(lookback_start, Time.current)
                                .count
    
    puts "  Eligible for scanning: #{eligible_messages}"
    
    if eligible_messages == 0
      puts "\n⚠️  No eligible messages found!"
      puts "\nPossible reasons:"
      puts "  - All messages are already in feed (run: bundle exec rails feed:reset_in_feed)"
      puts "  - All messages are too old (run: bundle exec rails feed:shift_timestamps[2,true])"
      puts "  - All messages are in conversation rooms (these are excluded)"
      exit
    end
    
    puts "\n" + "=" * 80
    puts "Running scan..."
    puts "=" * 80
    
    conversations = AutomatedFeed::Scanner.scan
    
    puts "\nScan results:"
    puts "  Conversations detected: #{conversations.count}"
    
    if conversations.empty?
      puts "\n⚠️  No conversations detected by AI"
      puts "\nPossible reasons:"
      puts "  - AI didn't find conversations meeting quality criteria"
      puts "  - AI Gateway API error (check logs)"
      puts "  - Messages don't meet engagement thresholds (3+ participants or 5+ messages)"
      exit
    end
    
    conversations.each_with_index do |conv, idx|
      puts "\n  Conversation #{idx + 1}:"
      puts "    Title: #{conv[:title]}"
      puts "    Summary: #{conv[:summary]}"
      puts "    Key insight: #{conv[:key_insight]}"
      puts "    Preview message ID: #{conv[:preview_message_id].inspect}"
      puts "    Message IDs: #{conv[:message_ids].inspect}"
      puts "    Participants: #{conv[:participants].inspect}"
      
      # Check deduplication
      dedup_result = AutomatedFeed::Deduplicator.check(conversation: conv)
      puts "    Deduplication: #{dedup_result[:action]}"
      if dedup_result[:reason]
        puts "      Reason: #{dedup_result[:reason]}"
      end
      if dedup_result[:card]
        puts "      Related card ID: #{dedup_result[:card].id}"
      end
    end
    
    puts "\n" + "=" * 80
    puts "Processing conversations..."
    puts "=" * 80
    
    conversations.each_with_index do |conversation, idx|
      puts "\nProcessing conversation #{idx + 1}: #{conversation[:title]}"
      puts "  DEBUG: preview_message_id in hash: #{conversation[:preview_message_id].inspect}"
      puts "  DEBUG: key_insight in hash: #{conversation[:key_insight].inspect}"
      
      begin
        dedup_result = AutomatedFeed::Deduplicator.check(conversation: conversation)
        
        case dedup_result[:action]
        when :skip
          puts "  → Skipped: #{dedup_result[:reason]}"
        when :new_topic
          puts "  → Creating new feed card..."
          result = RoomCreator.create_conversation_room(
            message_ids: conversation[:message_ids],
            title: conversation[:title],
            summary: conversation[:summary],
            key_insight: conversation[:key_insight],
            preview_message_id: conversation[:preview_message_id],
            type: "automated",
            promoted_by: nil
          )
          puts "  → ✓ Created successfully! (preview saved: #{result[:feed_card].preview_message_id})"
        when :continuation
          puts "  → Updating existing card #{dedup_result[:card].id}..."
          AutomatedFeed::RoomUpdater.update_continuation(
            feed_card: dedup_result[:card],
            new_message_ids: conversation[:message_ids],
            updated_summary: nil
          )
          puts "  → ✓ Updated successfully!"
        else
          puts "  → Unknown action: #{dedup_result[:action]}"
        end
      rescue => e
        puts "  → ✗ Error: #{e.class} - #{e.message}"
        puts "     #{e.backtrace.first(3).join("\n     ")}"
      end
    end
    
    puts "\n" + "=" * 80
    puts "Final stats:"
    puts "=" * 80
    
    total_cards = AutomatedFeedCard.count
    automated_cards = AutomatedFeedCard.automated.count
    recent_cards = AutomatedFeedCard.where("created_at >= ?", 1.hour.ago).count
    
    puts "  Total automated feed cards: #{automated_cards}"
    puts "  Cards created in last hour: #{recent_cards}"
    
    if recent_cards > 0
      puts "\n  Recent cards:"
      AutomatedFeedCard.where("created_at >= ?", 1.hour.ago).order(created_at: :desc).limit(5).each do |card|
        puts "    - #{card.title} (#{card.created_at.strftime('%H:%M:%S')})"
      end
    end
    
    puts "\n" + "=" * 80
    puts "Done!"
    puts "=" * 80
  end

  desc "Shift message timestamps to recent (for testing with old data)"
  task :shift_timestamps, [:days_back, :reset_in_feed] => :environment do |_t, args|
    days_back = (args[:days_back] || "7").to_i
    reset_in_feed = args[:reset_in_feed] == "true"
    
    cutoff_time = days_back.days.ago
    
    puts "Finding messages from the last #{days_back} days (since #{cutoff_time.strftime('%Y-%m-%d %H:%M:%S')})..."
    
    messages = Message.active
                      .where("created_at >= ?", cutoff_time)
                      .where.not(room_id: Room.where.not(source_room_id: nil).select(:id))
                      .order(:created_at)
    
    count = messages.count
    puts "Found #{count} messages to shift"
    
    if count == 0
      puts "No messages found to shift"
      exit
    end
    
    # Find the most recent message
    most_recent_message = messages.last
    most_recent_time = most_recent_message.created_at
    
    # Calculate delta: how much to shift to make the most recent message appear as "now"
    time_delta = Time.current - most_recent_time
    
    puts "\nMost recent message: #{most_recent_time.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "Shifting all messages forward by #{time_delta.to_i} seconds (#{(time_delta / 1.hour).round(2)} hours)"
    puts "Most recent message will appear as: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    
    if reset_in_feed
      puts "\nResetting in_feed flags..."
      messages.update_all(in_feed: false)
      puts "Reset in_feed flags for #{count} messages"
    end
    
    puts "\nShifting timestamps (preserving relative timing)..."
    
    batch_size = 100
    processed = 0
    
    messages.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |message|
        new_time = message.created_at + time_delta
        message.update_columns(
          created_at: new_time,
          updated_at: message.updated_at + time_delta
        )
      end
      
      processed += batch.size
      if processed % 1000 == 0 || processed == count
        puts "  Processed #{processed} / #{count} messages..."
      end
    end
    
    puts "\n✓ Shifted #{count} messages forward"
    puts "  Oldest message: #{cutoff_time.strftime('%Y-%m-%d %H:%M:%S')} → #{(cutoff_time + time_delta).strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  Most recent: #{most_recent_time.strftime('%Y-%m-%d %H:%M:%S')} → #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  Relative timing preserved ✓"
  end

  desc "Reset in_feed flags for messages (makes them eligible for scanning again)"
  task reset_in_feed: :environment do
    count = Message.in_feed.count
    puts "Found #{count} messages in feed"
    
    if count > 0
      puts "Resetting in_feed flags..."
      Message.in_feed.update_all(in_feed: false)
      puts "Reset in_feed flags for #{count} messages"
    else
      puts "No messages in feed found"
    end
  end

  desc "Delete all feed cards and their rooms (for testing cleanup)"
  task cleanup_all: :environment do
    total_cards = AutomatedFeedCard.count
    
    puts "Found #{total_cards} feed cards to delete"
    
    if total_cards == 0
      puts "No feed cards to delete"
      exit
    end
    
    print "Are you sure you want to delete ALL feed cards and their rooms? (y/N): "
    confirmation = $stdin.gets.chomp.downcase
    
    unless confirmation == "y"
      puts "Cancelled"
      exit
    end
    
    deleted_count = 0
    
    AutomatedFeedCard.find_each do |card|
      ActiveRecord::Base.transaction do
        room = card.room
        puts "Deleting card #{card.id}: #{card.title}"
        card.destroy
        room.deactivate if room
        deleted_count += 1
      end
    rescue => e
      puts "  ✗ Error deleting card #{card.id}: #{e.message}"
    end
    
    puts "\n✓ Deleted #{deleted_count} feed cards and their rooms"
    
    # Reset ALL in_feed flags (simpler and more reliable)
    in_feed_count = Message.in_feed.count
    if in_feed_count > 0
      puts "\nResetting in_feed flags on #{in_feed_count} messages..."
      Message.in_feed.update_all(in_feed: false)
      puts "✓ Reset in_feed flags"
    end
  end

  desc "Show feed stats"
  task stats: :environment do
    total_cards = AutomatedFeedCard.count
    automated_cards = AutomatedFeedCard.automated.count
    promoted_cards = AutomatedFeedCard.promoted.count
    
    recent_cards = AutomatedFeedCard.where("created_at >= ?", 24.hours.ago).count
    
    puts "Feed Stats:"
    puts "  Total cards: #{total_cards}"
    puts "  Automated cards: #{automated_cards}"
    puts "  Promoted cards: #{promoted_cards}"
    puts "  Cards in last 24h: #{recent_cards}"
    
    in_feed_messages = Message.in_feed.count
    total_messages = Message.active.count
    puts "\nMessages:"
    puts "  In feed: #{in_feed_messages}"
    puts "  Total active: #{total_messages}"
    puts "  Percentage: #{(in_feed_messages.to_f / total_messages * 100).round(2)}%"
  end

  desc "Sync active state from original messages to copied messages (one-time fix for existing data)"
  task sync_copied_message_active_state: :environment do
    puts "Finding copied messages that don't match their original message's active state..."
    
    # Find all copied messages where the active state doesn't match the original
    mismatched_messages = Message.where.not(original_message_id: nil)
                                 .joins("INNER JOIN messages AS originals ON messages.original_message_id = originals.id")
                                 .where("messages.active != originals.active")
    
    total_count = mismatched_messages.count
    
    if total_count == 0
      puts "✓ All copied messages already match their original messages' active state"
      exit
    end
    
    puts "Found #{total_count} copied messages with mismatched active state"
    
    # Get breakdown
    deactivate_count = mismatched_messages.where("messages.active = true AND originals.active = false").count
    reactivate_count = mismatched_messages.where("messages.active = false AND originals.active = true").count
    
    puts "  #{deactivate_count} to deactivate (original is inactive)"
    puts "  #{reactivate_count} to reactivate (original is active)"
    
    puts "\nSyncing active state..."
    
    # Deactivate copied messages where original is inactive
    deactivated = Message.where(id: mismatched_messages.where("messages.active = true AND originals.active = false").pluck(:id))
                        .update_all(active: false)
    
    # Reactivate copied messages where original is active  
    reactivated = Message.where(id: mismatched_messages.where("messages.active = false AND originals.active = true").pluck(:id))
                        .update_all(active: true)
    
    puts "\n✓ Synced #{deactivated + reactivated} copied messages"
    puts "  Deactivated: #{deactivated}"
    puts "  Reactivated: #{reactivated}"
    
    puts "\nNote: This was a one-time fix for existing data."
    puts "Going forward, the Message model will automatically sync changes."
  end
end
