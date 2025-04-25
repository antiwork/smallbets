class WelcomeController < ApplicationController
  def show
    render
  end

  private
    def landing_room
      Current.user.rooms.first
    end
end
