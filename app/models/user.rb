class User < ApplicationRecord
  DEFAULT_NAME = "Small Better"

  has_subscriptions
  after_create_commit :subscribe_to_emails

  include Avatar, Bot, Mentionable, Role, Transferable, Deactivatable, Preferences

  has_many :memberships, -> { active }, class_name: "Membership"
  has_many :rooms, -> { active }, through: :memberships, source: :room

  has_many :bookmarks, -> { active }, class_name: "Bookmark"
  has_many :bookmarked_messages, -> { order("bookmarks.created_at DESC") }, through: :bookmarks, source: :message
  has_many :reachable_messages, through: :rooms, source: :messages
  has_many :messages, -> { active }, foreign_key: :creator_id, class_name: "Message"

  has_many :mentions

  def mentioning_messages
    Message.active
      .where(room_id: room_ids)
      .left_joins(:mentions, :room)
      .where("mentions.user_id = ? OR messages.mentions_everyone = ? OR rooms.type = ?", id, true, "Rooms::Direct")
      .distinct
  end

  has_many :push_subscriptions, class_name: "Push::Subscription", dependent: :delete_all

  has_many :boosts, -> { active }, foreign_key: :booster_id, class_name: "Boost"
  has_many :searches, dependent: :delete_all
  has_many :promoted_feed_cards, class_name: "AutomatedFeedCard", foreign_key: :promoted_by_user_id

  has_many :sessions, dependent: :destroy
  has_many :auth_tokens, dependent: :destroy

  has_many :blocks_given, class_name: "Block", foreign_key: :blocker_id, dependent: :destroy
  has_many :blocked_users, through: :blocks_given, source: :blocked

  has_many :blocks_received, class_name: "Block", foreign_key: :blocked_id, dependent: :destroy
  has_many :blocked_by_users, through: :blocks_received, source: :blocker

  validates_presence_of :email_address, if: :person?
  normalizes :email_address, with: ->(email_address) { email_address.downcase }

  scope :without_default_names, -> { where.not(name: DEFAULT_NAME) }
  scope :non_suspended, -> { where(suspended_at: nil) }
  scope :unclaimed_gumroad_imports, -> { where.not(order_id: nil).where(last_authenticated_at: nil) }

  has_secure_password validations: false

  before_validation :set_default_name
  before_validation :normalize_social_urls
  before_save :transliterate_name, if: :name_changed?
  after_create_commit :grant_membership_to_open_rooms

  # Clear the all_time_ranks cache when users are created, deleted, or their status changes
  after_create_commit -> { StatsService.clear_all_time_ranks_cache }
  after_destroy_commit -> { StatsService.clear_all_time_ranks_cache }
  after_update_commit -> { StatsService.clear_all_time_ranks_cache if saved_change_to_attribute?(:active) || saved_change_to_attribute?(:suspended_at) }

  scope :ordered, -> { order("LOWER(name)") }
  scope :recent_posters_first, ->(room_id = nil) do
    messages_table = Message.active.arel_table
    users_table = active.arel_table

    left_join_condition = messages_table[:creator_id].eq(users_table[:id])
    left_join_condition = left_join_condition.and(messages_table[:room_id].eq(room_id)) if room_id.present?

    left_join = users_table.join(messages_table, Arel::Nodes::OuterJoin).on(left_join_condition)

    joins(left_join.join_sources)
      .group(users_table[:id])
      .order(messages_table[:created_at].maximum.desc)
  end
  scope :by_first_name, ->(first_name) { where("CASE WHEN instr(name, ' ') > 0 THEN substr(name, 1, instr(name, ' ')-1) ELSE name END = ?", first_name.to_s.strip) }
  scope :filtered_by, ->(query) { where("name like ? or ascii_name like ? or twitter_username like ? or linkedin_username like ?",
                                        "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%") if query.present? }

  def self.from_gumroad_sale(attributes)
    return nil unless attributes[:email_address].present?

    unclaimed_gumroad_import = find_and_initialize_unclaimed_gumroad_import(attributes)
    return unclaimed_gumroad_import if unclaimed_gumroad_import.present?

    if ENV["GUMROAD_ON"] == "true"
      find_or_create_user_from_gumroad(attributes)
    else
      find_or_create_user_locally(attributes)
    end
  end

  def imported_from_gumroad_and_unclaimed?
    order_id.present? && last_authenticated_at.nil?
  end

  def ever_authenticated?
    last_authenticated_at.present?
  end

  def initials
    name.scan(/\b\w/).join
  end

  def title
    [ name, bio ].compact_blank.join(" – ")
  end

  def reactivate
    transaction do
      memberships.without_direct_rooms.update!(active: true)

      update! active: true, email_address: reactivated_email_address

      reset_remote_connections
    end
  end

  def deactivate
    transaction do
      close_remote_connections

      memberships.without_direct_rooms.update!(active: false)
      push_subscriptions.delete_all
      searches.delete_all
      sessions.delete_all

      update! active: false, email_address: deactived_email_address
    end
  end

  def reset_remote_connections
    close_remote_connections reconnect: true
  end

  def member_of?(room)
    Membership.active.visible.exists?(room_id: room.id, user_id: id)
  end

  def default_name?
    name == DEFAULT_NAME
  end

  def editable_name
    default_name? ? "" : name
  end

  def joined_at
    membership_started_at || created_at
  end

  def suspended?
    suspended_at.present?
  end

  def suspend!
    update!(suspended_at: Time.current) unless suspended?
  end

  def ensure_can_sign_in!
    update!(suspended_at: nil)
  end

  def total_message_count
    Message.active
           .joins(:room)
           .where(creator_id: id)
           .where("rooms.type != ?", "Rooms::Direct")
           .count
  end

  def message_rank
    # Use the centralized ranking method from StatsService
    StatsService.calculate_all_time_rank(id)
  end

  def subscribed_to_emails?
    subscribed?("notifications")
  end

  def subscribe_to_emails
    subscribe("notifications")
  end

  def unsubscribe_from_emails
    unsubscribe("notifications")
  end

  def toggle_email_subscription
    subscribed_to_emails? ? unsubscribe_from_emails : subscribe_to_emails
  end

  def blocked_in?(room)
    return false unless room.one_on_one?

    !can_ping?(room.roommate_to(self))
  end

  def can_ping?(other_user)
    !blocked?(other_user) && !blocked_by?(other_user)
  end

  def blocked?(other_user)
    blocked_users.exists?(other_user&.id)
  end

  def blocked_by?(other_user)
    blocked_by_users.exists?(other_user&.id)
  end

  def block!(other_user)
    blocks_given.find_or_create_by!(blocked: other_user)
  end

  def unblock!(other_user)
    blocks_given.where(blocked: other_user).destroy_all
  end

  private
    def self.find_and_initialize_unclaimed_gumroad_import(attributes)
      unclaimed_gumroad_import = User.active.non_suspended.unclaimed_gumroad_imports.find_by(email_address: attributes[:email_address])

      unclaimed_gumroad_import&.update!(attributes)
      unclaimed_gumroad_import
    end

    def self.find_or_create_user_from_gumroad(attributes)
      sale = GumroadAPI.successful_membership_sale(email: attributes[:email_address])
      User.create!(attributes.merge(membership_started_at: sale["created_at"], order_id: sale["order_id"])) if sale
    rescue ActiveRecord::RecordNotUnique
      user = User.active.find_by(email_address: attributes[:email_address])

      if user.present?
        # Link the latest successful sale to user,
        user.order_id = sale["order_id"]
        # but keep the old join date (`membership_started_at`) if present.
        user.membership_started_at = user.membership_started_at || sale["created_at"]
        # We have found a successful gumroad sale, so make sure the user is not suspended for a full refund of a previous sale.
        user.suspended_at = nil
        user.save!
      end

      user
    end

    def self.find_or_create_user_locally(attributes)
      User.create!(attributes)
    rescue ActiveRecord::RecordNotUnique
      User.active.find_by(email_address: attributes[:email_address])
    end

    def grant_membership_to_open_rooms
      Membership.insert_all(Rooms::Open.active.pluck(:id).collect { |room_id| { room_id: room_id, user_id: id } })
      Rooms::Thread.joins(:parent_room).where(parent_room: { type: "Rooms::Open" }).find_each do |thread|
        thread.memberships.grant_to(self)
      end
    end

    def reactivated_email_address
      email_address&.gsub(/-deactivated-.+@/, "@")
    end

    def deactived_email_address
      email_address&.gsub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end

    def close_remote_connections(reconnect: false)
      ActionCable.server.remote_connections.where(current_user: self).disconnect reconnect: reconnect
    end

    def set_default_name
      self.name = name.presence || DEFAULT_NAME
    end

    def transliterate_name
      self.ascii_name = name.to_s.to_ascii
    end

    def normalize_social_urls
      self.twitter_url = clean_twitter_url(twitter_url)
      self.linkedin_url = clean_linkedin_url(linkedin_url)
    end

    def clean_twitter_url(url)
      return nil if url.blank?
      return url.strip if url.include?("/")

      handle = url.gsub(/^@/, "").strip
      "https://x.com/#{handle}"
    end

    def clean_linkedin_url(url)
      return nil if url.blank?
      return url.strip if url.strip.match?(/\/.+/)

      handle = url.strip
      "https://www.linkedin.com/in/#{handle}"
    end
end
