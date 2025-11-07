class Message < ApplicationRecord
  include Attachment, Broadcasts, Mentionee, Pagination, Searchable, Deactivatable, Answerable

  belongs_to :room, counter_cache: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :original_message, class_name: "Message", optional: true
  has_many :copied_messages, class_name: "Message", foreign_key: :original_message_id

  has_many :boosts, -> { active.order(:created_at) }, class_name: "Boost"
  has_many :bookmarks, -> { active }, class_name: "Bookmark"

  has_many :threads, -> { active }, class_name: "Rooms::Thread", foreign_key: :parent_message_id

  has_rich_text :body

  before_create -> { self.client_message_id ||= Random.uuid } # Bots don't care
  before_create :touch_room_activity
  after_create_commit -> { room.receive(self) }
  after_update_commit -> do
    if saved_change_to_attribute?(:active) && active?
      broadcast_reactivation
    end
  end
  after_update_commit :clear_unread_timestamps_if_deactivated
  after_update_commit :broadcast_parent_message_to_threads
  after_update_commit -> { update_thread_reply_count_on_deactivation }
  after_update_commit :deactivate_copied_messages_on_deactivation

  after_create_commit -> { involve_mentionees_in_room(unread: true) }
  after_create_commit -> { involve_creator_in_thread }
  after_create_commit -> { update_thread_reply_count }
  after_create_commit -> { update_parent_message_threads }
  after_create_commit -> { track_automated_feed_activity }
  after_update_commit -> { involve_mentionees_in_room(unread: false) }

  # Clear the all_time_ranks cache when messages are created or deleted
  after_create_commit -> { StatsService.clear_all_time_ranks_cache }
  after_destroy_commit -> { StatsService.clear_all_time_ranks_cache }
  after_update_commit -> { StatsService.clear_all_time_ranks_cache if saved_change_to_attribute?(:active) }

  scope :ordered, -> { order(:created_at) }
  scope :with_creator, -> { includes(:creator).merge(User.with_attached_avatar) }
  scope :with_threads, -> { includes(threads: { visible_memberships: :user }) }
  scope :with_original_message, -> { includes(original_message: :room) }
  scope :created_by, ->(user) { where(creator_id: user.id) }
  scope :without_created_by, ->(user) { where.not(creator_id: user.id) }
  scope :between, ->(from, to) { where(created_at: from..to) }
  scope :since, ->(time) { where(created_at: time..) }
  scope :in_feed, -> { where(in_feed: true) }
  scope :not_in_feed, -> { where(in_feed: false) }

  attr_accessor :bookmarked
  alias_method :bookmarked?, :bookmarked

  validate :ensure_can_message_recipient, on: :create
  validate :ensure_everyone_mention_allowed, on: :create

  def bookmarked_by_current_user?
    return bookmarked? unless bookmarked.nil?

    bookmarks.find_by(user_id: Current.user&.id).present?
  end

  def plain_text_body
    body.to_plain_text.presence || attachment&.filename&.to_s || ""
  end

  def to_key
    [ client_message_id ]
  end

  def content_type
    case
    when attachment?    then "attachment"
    when sound.present? then "sound"
    else                     "text"
    end.inquiry
  end

  def sound
    plain_text_body.match(/\A\/play (?<name>\w+)\z/) do |match|
      Sound.find_by_name match[:name]
    end
  end

  private

  def track_automated_feed_activity
    result = AutomatedFeed::ActivityTracker.record(self)
    return unless result[:trigger?]
    return unless result[:room_id]

    AutomatedFeed::RoomScanJob.perform_later(result[:room_id], trigger_status: result[:status])
  end

  def involve_mentionees_in_room(unread:)
    # Skip auto-involvement for @everyone to avoid creating thousands of membership updates
    # Users already in the room will be notified via the updated queries
    return if mentions_everyone?

    mentionees.each { |user| room.involve_user(user, unread: unread) }
  end

  def involve_creator_in_thread
    # When someone posts in a thread, ensure they have visible membership
    if room.thread?
      room.involve_user(creator, unread: false)
    end
  end

  def update_thread_reply_count_on_deactivation
    # When a message is deleted in a thread, update the reply count separator
    if saved_change_to_attribute?(:active) && !active? && room.thread?
      room.reload # Reload to get updated counter cache
      active_count = room.messages.active.count
      parent_message = room.parent_message # Capture before deactivation
      
      broadcast_update_to(
        room,
        :messages,
        target: "#{ActionView::RecordIdentifier.dom_id(room, :replies_separator)}_count",
        html: ActionController::Base.helpers.pluralize(active_count, 'reply', 'replies')
      )
      
      # If thread is now empty, deactivate it BEFORE updating parent message display
      # This ensures the parent message's threads display excludes the empty thread
      if active_count == 0
        room.deactivate
      end
      
      # Update parent message threads display (after deactivation if thread was empty)
      if parent_message
        # Reload parent message to get updated threads association (which filters by active)
        parent_message.reload
        broadcast_replace_to(
          parent_message.room,
          :messages,
          target: ActionView::RecordIdentifier.dom_id(parent_message, :threads),
          partial: "messages/threads",
          locals: { message: parent_message }
        )
      end
    end
  end

  def update_thread_reply_count
    # When a message is created in a thread, update the reply count separator
    if room.thread?
      broadcast_update_to(
        room,
        :messages,
        target: "#{ActionView::RecordIdentifier.dom_id(room, :replies_separator)}_count",
        html: ActionController::Base.helpers.pluralize(room.messages_count, 'reply', 'replies')
      )
    end
  end

  def update_parent_message_threads
    # When a message is created in a thread, update the parent message's threads display
    if room.thread? && room.parent_message
      broadcast_replace_to(
        room.parent_message.room,
        :messages,
        target: ActionView::RecordIdentifier.dom_id(room.parent_message, :threads),
        partial: "messages/threads",
        locals: { message: room.parent_message }
      )
    end
  end

  def broadcast_parent_message_to_threads
    # When a parent message is deleted/updated, broadcast to all threads
    if saved_change_to_attribute?(:active) && threads.any?
      threads.each do |thread|
        broadcast_replace_to(
          thread,
          :messages,
          target: ActionView::RecordIdentifier.dom_id(self),
          partial: "messages/parent_message",
          locals: { message: self, thread: thread }
        )
      end
    end
  end

  def deactivate_copied_messages_on_deactivation
    # When an original message is deactivated/reactivated, sync the state to all copied messages
    # This ensures digest/conversation rooms reflect the current state of messages in the source room
    if saved_change_to_attribute?(:active) && copied_messages.any?
      copied_messages.update_all(active: active)
    end
  end

  def touch_room_activity
    room.touch(:last_active_at)
  end

  private

  def ensure_can_message_recipient
    errors.add(:base, "Messaging this user isn't allowed") if creator.blocked_in?(room)
  end

  def ensure_everyone_mention_allowed
    return unless body.body

    has_everyone_mention = body.body.attachables.any? { |a| a.is_a?(Everyone) }
    return unless has_everyone_mention

    if !room.is_a?(Rooms::Open)
      errors.add(:base, "@everyone is only allowed in open rooms")
    elsif !creator&.administrator?
      errors.add(:base, "Only admins can mention @everyone")
    end
  end

  private

  def clear_unread_timestamps_if_deactivated
    if saved_change_to_attribute?(:active) && !active?
      # Find memberships where unread_at points to this deleted message
      room.memberships.where(unread_at: created_at).find_each do |membership|
        # Find the next unread message after this one, or mark as read
        next_unread = room.messages.active.ordered
                         .where("created_at > ?", created_at)
                         .first

        if next_unread
          membership.update!(unread_at: next_unread.created_at)
        else
          membership.read # This sets unread_at to nil and broadcasts read status
        end
      end
    end
  end
end
