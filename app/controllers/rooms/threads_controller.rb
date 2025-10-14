class Rooms::ThreadsController < RoomsController
  before_action :set_parent_message, only: %i[ new ]

  def new
    # Check if thread already exists for this message (there can only be one)
    existing_thread = @parent_message.threads.active.find_by(type: 'Rooms::Thread')

    if existing_thread
      redirect_to room_url(existing_thread)
    else
      @room = Rooms::Thread.create_for({ parent_message_id: @parent_message.id }, users: parent_room.users)
      redirect_to room_url(@room)
    end
  end

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
  def set_parent_message
    if message = Current.user.reachable_messages.joins(:room).where.not(room: { type: "Rooms::Direct" }).find_by(id: params[:parent_message_id])
      @parent_message = message
    else
      redirect_to root_url, alert: "Message not found or inaccessible"
    end
  end

  def parent_room
    @parent_message.room
  end

  def room_params
    params.require(:room).permit(:name)
  end
end
