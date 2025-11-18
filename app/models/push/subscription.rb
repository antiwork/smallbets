class Push::Subscription < ApplicationRecord
  belongs_to :user

  def notification(**params)
    unread_memberships = user.memberships.unread.with_has_unread_notifications.includes(:room)
    badge = unread_memberships.count { |m| m.has_unread_notifications? }
    
    WebPush::Notification.new(**params, badge: badge, endpoint: endpoint, p256dh_key: p256dh_key, auth_key: auth_key)
  end
end
