class Messages::UnreadsController < ApplicationController
  before_action :set_message
  before_action :set_room
  before_action :set_membership

  def create
    @membership.mark_unread_at(@message)
  end

  private
    def set_message
      @message = Current.user.reachable_messages.find(params[:message_id])
    end

    def set_room
      @room = Current.user.rooms.find(params[:room_id])
    end

    def set_membership
      @membership = Current.user.memberships.find_by!(room_id: @room.id)
    end
end
