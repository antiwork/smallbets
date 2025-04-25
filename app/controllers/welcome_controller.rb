class WelcomeController < ApplicationController
  def show
    if Current.user.rooms.any?
      redirect_to room_url(landing_room)
    else
      render
    end
  end

  private
    def landing_room
      Current.user.rooms.first
    end
end
