class Rooms::ThreadsController < RoomsController
  def edit
    @users = @room.visible_users.active.includes(avatar_attachment: :blob).ordered
  end

  def update
    @room.update! room_params

    redirect_to room_url(@room)
  end

  def destroy
    deactivate_room
    redirect_to room_at_message_path(@room.parent_message.room, @room.parent_message)
  end
  
  private
  def room_params
    params.require(:room).permit(:name)
  end
end
