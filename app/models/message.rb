class Message < ApplicationRecord
  include Attachment, Broadcasts, Mentionee, Pagination, Searchable, Deactivatable

  belongs_to :room, counter_cache: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :boosts, -> { active }, class_name: "Boost"
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

  after_create_commit -> { involve_mentionees_in_room(unread: true) }
  after_update_commit -> { involve_mentionees_in_room(unread: false) }

  scope :ordered, -> { order(:created_at) }
  scope :with_creator, -> { includes(:creator) }
  scope :with_threads, -> { includes(:threads) }
  scope :created_by, ->(user) { where(creator_id: user.id) }
  scope :without_created_by, ->(user) { where.not(creator_id: user.id) }
  scope :between, ->(from, to) { where(created_at: from..to) }
  scope :since, ->(time) { where(created_at: time..) }

  attr_accessor :bookmarked
  alias_method :bookmarked?, :bookmarked
  
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

  def involve_mentionees_in_room(unread:)
    mentionees.each { |user| room.involve_user(user, unread: unread) }
  end

  def touch_room_activity
    room.touch(:last_active_at)
  end
end
