module RoomScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_room
  end

  private
    def set_room
      @membership = Current.user.memberships.find_by!(room_id: params[:room_id])
      @room = @membership.room
      enforce_feed_conversation_access!(@room)
    end

    def set_room_if_found
      @membership = Current.user.memberships.find_by(room_id: params[:room_id])
      @room = @membership&.room
      enforce_feed_conversation_access!(@room) if @room
    end
end
