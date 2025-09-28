class Room < ApplicationRecord
  include Deactivatable

  has_many :memberships, -> { active } do
    def grant_to(users)
      room = proxy_association.owner
      Membership.upsert_all(
        Array(users).collect { |user| { room_id: room.id, user_id: user.id, involvement: room.default_involvement(user: user), active: true } },
        unique_by: %i[room_id user_id]
      )
      room.threads.find_each { |thread| thread.memberships.grant_to(users) }
    end

    def revoke_from(users)
      room = proxy_association.owner
      # Must use the `user_id: ...` condition and not `user: ...` for the hierarchical permissions to work
      Membership.active.where(room_id: room.id, user_id: Array(users).map(&:id)).update(active: false)
      room.threads.find_each { |thread| thread.memberships.revoke_from(users) }
    end

    def revise(granted: [], revoked: [])
      transaction do
        grant_to(granted) if granted.present?
        revoke_from(revoked) if revoked.present?
      end
    end
  end

  has_many :users, -> { active }, through: :memberships, class_name: "User"
  has_many :visible_memberships, -> { active.visible }, class_name: "Membership"
  has_many :visible_users, through: :visible_memberships, source: :user, class_name: "User"
  has_many :messages, -> { active }, class_name: "Message"
  has_one :last_message, -> { active.order(created_at: :desc) }, class_name: "Message"
  has_many :threads, through: :messages, class_name: "Rooms::Thread"
  belongs_to :parent_message, class_name: "Message", optional: true, touch: true
  has_one :parent_room, through: :parent_message, source: :room, class_name: "Room"

  belongs_to :creator, class_name: "User", default: -> { Current.user }

  before_validation -> { self.last_active_at = Time.current }, on: :create

  before_save :set_sortable_name
  before_validation :normalize_slug

  after_save_commit :broadcast_updates, if: :saved_change_to_sortable_name?

  scope :opens,           -> { where(type: "Rooms::Open") }
  scope :closeds,         -> { where(type: "Rooms::Closed") }
  scope :directs,         -> { where(type: "Rooms::Direct") }
  scope :without_directs, -> { where.not(type: "Rooms::Direct") }

  scope :ordered, -> { order(:sortable_name) }

  RESERVED_SLUGS = %w[
    join api chat rooms users messages library experts stats up service-worker webmanifest account session auth_tokens webhooks configurations inbox searches qr_code assets rails
  ]

  validates :slug,
            allow_nil: true,
            uniqueness: { case_sensitive: false },
            length: { maximum: 80 },
            format: { with: /\A[a-z0-9](?:[a-z0-9\-]*[a-z0-9])\z/, message: "use lowercase letters, numbers, and hyphens; no leading/trailing hyphen" }
  validate :slug_not_reserved

  after_update_commit -> do
    if saved_change_to_attribute?(:active) && active?
      broadcast_reactivation
    end
  end

  class << self
    def create_for(attributes, users:)
      transaction do
        create!(attributes).tap do |room|
          room.memberships.grant_to users
        end
      end
    end

    def original
      order(:created_at).first
    end
  end

  def receive(message)
    unread_memberships(message)
    push_later(message)
  end

  def involve_user(user, unread: false)
    membership = memberships.create_with(involvement: "mentions").find_or_create_by(user: user)
    membership.update(unread_at: messages.last&.created_at || Time.current) if unread && membership.read?
    membership.ensure_receives_mentions!
  end

  def open?
    is_a?(Rooms::Open)
  end

  def closed?
    is_a?(Rooms::Closed)
  end

  def direct?
    is_a?(Rooms::Direct)
  end

  def one_on_one?
    direct? && memberships.count == 2
  end

  def roommate_to(user)
    return nil unless one_on_one?

    users.without(user).first
  end

  def thread?
    is_a?(Rooms::Thread)
  end

  def default_involvement(user: nil)
    "mentions"
  end

  def reactivate
    transaction do
      memberships.rewhere(active: false).update(active: true)
      messages.rewhere(active: false).update(active: true)
      threads.rewhere(active: false).update(active: true)

      activate!
    end
  end

  def merge_into!(target_room)
    transaction do
      memberships.update(active: false)
      messages.update(room_id: target_room.id)
      Message::RichTextUpdater.update_room_links_in_quoted_messages(from: id, to: target_room.id)

      deactivate!
    end
  end

  def deactivate
    transaction do
      memberships.update_all(active: false)
      messages.update_all(active: false)
      threads.update_all(active: false)

      deactivate!
    end
  end

  private
    def set_sortable_name
      self.sortable_name = name.to_s.gsub(/[[:^ascii:]\p{So}]/, "").strip.downcase
    end

    def normalize_slug
      return if slug.nil?
      self.slug = slug.to_s.strip.downcase.gsub(/\s+/, "-")
      self.slug = nil if self.slug.blank?
    end

    def slug_not_reserved
      return if slug.blank?
      errors.add(:slug, "is reserved") if RESERVED_SLUGS.include?(slug)
    end

    def unread_memberships(message)
      memberships.visible.disconnected.read.where.not(user: message.creator).update_all(unread_at: message.created_at, updated_at: Time.current)
    end

    def push_later(message)
      Room::PushMessageJob.perform_later(self, message)
    end

    def broadcast_updates
      ActionCable.server.broadcast "room_list", { roomId: id, sortableName: sortable_name }
    end

    def broadcast_reactivation
      [ :starred_rooms, :shared_rooms ].each do |list_name|
        broadcast_append_to :rooms, target: list_name, partial: "users/sidebars/rooms/shared", locals: { list_name:, room: self }, attributes: { maintain_scroll: true }
      end
    end
end
