class WelcomeController < ApplicationController
  def show
    if Current.user.rooms.any?
      room = landing_room
      target = room.slug.present? ? room_slug_url(room.slug) : room_url(room)
      target = target + "?" + request.query_string if request.query_string.present?
      redirect_to target
    else
      render
    end
  end
end
