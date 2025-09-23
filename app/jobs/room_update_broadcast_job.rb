class RoomUpdateBroadcastJob < ApplicationJob
  queue_as :default

  def perform(room)
    for_each_sidebar_section do |list_name|
      each_user_and_html_for(room, list_name:) do |user, html|
        broadcast_replace_to user, :rooms, target: [ room, helpers.dom_prefix(list_name, :list_node) ], html: html
      end
    end
  end

  private

  def each_user_and_html_for(room, **locals)
    html_cache = {}

    room.memberships.visible.includes(:user).with_has_unread_notifications.each do |membership|
      yield membership.user, render_or_cached(html_cache,
                                              partial: "users/sidebars/rooms/shared",
                                              locals: { membership: membership, list_name: locals[:list_name], room: room })
    end
  end

  def render_or_cached(cache, partial:, locals:)
    cache[locals[:list_name]] ||= ApplicationController.render(partial: partial, locals: locals)
  end

  def for_each_sidebar_section
    [ :starred_rooms, :shared_rooms ].each do |name|
      yield name
    end
  end

  def broadcast_replace_to(stream, *args)
    Turbo::StreamsChannel.broadcast_replace_to(stream, *args)
  end

  def helpers
    ApplicationController.helpers
  end
end
