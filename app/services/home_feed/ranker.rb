module HomeFeed
  class Ranker
    def self.top(limit: 50)
      cards = AutomatedFeedCard.includes(room: [:messages, :source_room])
                       .order(created_at: :desc)
                       .limit(limit * 2)
      
      return [] if cards.empty?
      
      room_ids = cards.map { |card| card.room_id }
      metrics = load_metrics(room_ids)
      earliest_times = load_earliest_times(room_ids)
      
      scored_cards = cards.map do |card|
        score = calculate_score(card, metrics, earliest_times[card.room_id])
        [card, score]
      end
      
      scored_cards.sort_by { |_, score| -score }
                  .first(limit)
                  .map(&:first)
    end
    
    def self.new(limit: 50)
      cards = AutomatedFeedCard.includes(room: [:messages, :source_room])
                       .order(created_at: :desc)
                       .limit(limit * 2)
      
      return [] if cards.empty?
      
      room_ids = cards.map { |card| card.room_id }
      earliest_times = load_earliest_times(room_ids)
      
      cards.map do |card|
        earliest_time = earliest_times[card.room_id]
        [card, earliest_time]
      end
          .select { |_, time| time.present? }
          .sort_by { |_, time| time }
          .reverse
          .first(limit)
          .map(&:first)
    end
    
    private
    
    def self.load_metrics(room_ids)
      message_counts = Message.active.where(room_id: room_ids).group(:room_id).count
      reaction_counts = Boost.active
                             .joins(:message)
                             .where(messages: { room_id: room_ids, active: true })
                             .group("messages.room_id")
                             .count
      bookmark_counts = Bookmark.active
                                .joins(:message)
                                .where(messages: { room_id: room_ids, active: true })
                                .group("messages.room_id")
                                .count
      
      room_ids.index_with do |room_id|
        {
          messages: message_counts[room_id] || 0,
          reactions: reaction_counts[room_id] || 0,
          bookmarks: bookmark_counts[room_id] || 0
        }
      end
    end
    
    def self.load_earliest_times(room_ids)
      Message.active
            .where(room_id: room_ids)
            .group(:room_id)
            .minimum(:created_at)
    end
    
    def self.calculate_score(card, metrics, earliest_time)
      room_metrics = metrics[card.room_id] || { messages: 0, reactions: 0, bookmarks: 0 }
      
      activity_score = (room_metrics[:messages] * 4.0) + room_metrics[:reactions] + room_metrics[:bookmarks]
      
      return activity_score.to_f if earliest_time.nil?
      
      recency_multiplier = calculate_recency_multiplier(earliest_time)
      activity_score * (1.0 + recency_multiplier * 0.3)
    end
    
    def self.calculate_recency_multiplier(earliest_time)
      hours_ago = (Time.current - earliest_time) / 1.hour
      if hours_ago <= 1
        1.0
      elsif hours_ago <= 24
        1.0 - (hours_ago / 24.0 * 0.5)
      elsif hours_ago <= 168
        0.5 - ((hours_ago - 24.0) / 144.0 * 0.4)
      else
        [0.0, 0.1 - ((hours_ago - 168.0) / 720.0)].max
      end
    end
  end
end
