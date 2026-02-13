class Rooms::EmailDigestExclusionsController < ApplicationController
  include RoomScoped

  before_action :ensure_can_administer

  def update
    @room.update!(exclude_from_digest: !@room.exclude_from_digest?)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: room_url(@room) }
    end
  end

  private
    def ensure_can_administer
      head :forbidden unless Current.user.administrator?
    end
end
