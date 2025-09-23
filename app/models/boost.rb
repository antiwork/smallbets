class Boost < ApplicationRecord
  include Deactivatable

  belongs_to :message, touch: true
  belongs_to :booster, class_name: "User", default: -> { Current.user }

  scope :ordered, -> { order(:created_at) }

  after_update_commit -> do
    if saved_change_to_attribute?(:active) && active?
      broadcast_reactivation
    end
  end

  private
    def broadcast_reactivation
      previous_boost = message.boosts.where("created_at < ?", created_at).last
      if previous_boost.present?
        target = previous_boost
        action = "after"
      else
        target = [ message.room, :messages ]
        action = "prepend"
      end

      broadcast_action_to message.room, :messages,
                          action:,
                          target:,
                          partial: "messages/boosts/boost",
                          locals: { boost: self }
    end
end
