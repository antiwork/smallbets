class RoomMembershipBroadcastJob < ApplicationJob
  queue_as :default

  # If the job fails due to a deadlock or other transient error, retry it.
  retry_on ActiveRecord::Deadlocked, wait: :exponentially, attempts: 3

  def perform(membership)
    return unless membership&.user && membership.room&.active?

    for_each_sidebar_section do |list_name|
      html = render_partial_for(membership, list_name)
      broadcast_replace_to membership.user, :rooms, target: [ membership.room, helpers.dom_prefix(list_name, :list_node) ], html: html
    end
  end

  private

  def render_partial_for(membership, list_name)
    ApplicationController.render(
      partial: "users/sidebars/rooms/shared",
      locals: { membership: membership, list_name: list_name, room: membership.room }
    )
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
