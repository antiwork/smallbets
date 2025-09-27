class Room::BroadcastUpdateJob < ApplicationJob
  include Turbo::Streams::Broadcasts
  include Turbo::Streams::StreamName

  def perform(room)
    for_each_sidebar_section do |list_name|
      broadcast_to_members(room, list_name)
    end
  end

  private
    def broadcast_to_members(room, list_name)
      html_cache = {}

      room.memberships.visible.includes(:user).with_has_unread_notifications.find_each do |membership|
        cache_key = {
          room_id: room.id,
          list_name:,
          involvement: membership.involvement,
          unread: membership.unread?,
          has_notifications: membership.has_unread_notifications?
        }
        
        html = html_cache[cache_key] ||= ApplicationController.render(
          partial: "users/sidebars/rooms/shared",
          locals: { membership:, list_name: }
        )
        
        broadcast_replace_to membership.user, :rooms, 
                            target: [ room, dom_prefix(list_name, :list_node) ], 
                            html: html
      end
    end

    def for_each_sidebar_section
      [ :starred_rooms, :shared_rooms ].each do |name|
        yield name
      end
    end

    def dom_prefix(list_name, node_type)
      "#{list_name}_#{node_type}"
    end
end